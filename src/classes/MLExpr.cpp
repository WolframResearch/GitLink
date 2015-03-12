#include "mathlink.h"
#include "MLExpr.h"
#include "git2.h"
#include "WolframLibrary.h"
#include "MLHelper.h"

MLExpr::MLExpr(MLINK lnk)
	: str_(NULL)
	, len_(0)
	, loopbackLink_(NULL)
{
	int err;
	if (lnk)
	{
		loopbackLink_ = MLLoopbackOpen(MLLinkEnvironment(lnk), &err);
		MLTransferExpression(loopbackLink_, lnk);
	}
}

MLExpr::MLExpr(const MLExpr& expr)
	: str_(NULL)
	, loopbackLink_(NULL)
	, len_(0)
{
	int err;
	if (expr.loopbackLink_ == NULL)
		return;
	loopbackLink_ = MLLoopbackOpen(MLLinkEnvironment(expr.loopbackLink_), &err);
	MLAutoMark mark(expr.loopbackLink_, true);
	MLTransferExpression(loopbackLink_, expr.loopbackLink_);
}

MLExpr::MLExpr(MLExpr&& expr)
	: str_(expr.str_)
	, loopbackLink_(expr.loopbackLink_)
	, len_(expr.len_)
{
	expr.str_ = NULL;
	expr.loopbackLink_ = NULL;
	expr.len_ = 0;
}

MLExpr& MLExpr::operator=(const MLExpr& expr)
{
	if (str_)
		MLReleaseUTF8String(loopbackLink_, (const unsigned char*)str_, len_);
	if (loopbackLink_ == NULL)
		MLClose(loopbackLink_);
	loopbackLink_ = NULL;

	str_ = NULL;
	len_ = 0;

	if (expr.loopbackLink_)
	{
		MLAutoMark mark(expr.loopbackLink_, true);
		int err;
		loopbackLink_ = MLLoopbackOpen(MLLinkEnvironment(expr.loopbackLink_), &err);
		MLTransferExpression(loopbackLink_, expr.loopbackLink_);
	}
	return *this;
}

MLExpr& MLExpr::operator=(MLExpr&& expr)
{
	str_ = expr.str_;						expr.str_ = NULL;
	loopbackLink_ = expr.loopbackLink_;		expr.loopbackLink_ = NULL;
	len_ = expr.len_;						expr.len_ = 0;
	return *this;
}

MLINK MLExpr::initializeLink(MLEnvironment env)
{
	int err;
	return (loopbackLink_ = MLLoopbackOpen(env, &err));
}

void MLExpr::putToLink(MLINK lnk) const
{
	MLAutoMark mark(loopbackLink_, true);
	MLTransferExpression(lnk, loopbackLink_);
}

MLINK MLExpr::putToLoopbackLink() const
{
	int err;
	MLINK loopback = MLLoopbackOpen(MLLinkEnvironment(loopbackLink_), &err);
	MLAutoMark mark(loopbackLink_, true);
	MLTransferExpression(loopback, loopbackLink_);
	return loopback;
}

bool MLExpr::testString(const char* str) const
{
	if (loopbackLink_ == NULL)
		return false;
	MLAutoMark mark(loopbackLink_, true);
	if (MLGetNext(loopbackLink_) == MLTKSTR)
	{
		MLString linkStr(loopbackLink_);
		return (strcmp(linkStr, str) == 0);
	}
	return false;
}

bool MLExpr::testSymbol(const char* sym) const
{
	if (loopbackLink_ == NULL)
		return false;
	MLAutoMark mark(loopbackLink_, true);
	if (MLGetNext(loopbackLink_) == MLTKSYM)
	{
		MLString linkStr(loopbackLink_);
		return (strcmp(linkStr, sym) == 0);
	}
	return false;
}

bool MLExpr::testHead(const char* sym) const
{
	if (loopbackLink_ == NULL)
		return false;
	{
		MLAutoMark mark(loopbackLink_, true);
		if (MLGetNext(loopbackLink_) != MLTKFUNC)
			return false;
	}
	return part(0).testSymbol(sym);
}

MLExpr MLExpr::part(int i) const
{
	int argCount;
	MLAutoMark mark(loopbackLink_, true);
	MLGetNext(loopbackLink_);
	MLGetArgCount(loopbackLink_, &argCount);

	for (int index = 0; index < i; index++)
	{
		MLExpr drainExpr(loopbackLink_);
	}
	return MLExpr(loopbackLink_);
}

int MLExpr::asInt() const
{
	MLAutoMark mark(loopbackLink_, true);
	int i;
	return (MLGetInteger(loopbackLink_, &i) == 0) ? 0 : i;
}

mint MLExpr::asMint() const
{
	MLAutoMark mark(loopbackLink_, true);
	mint i;
	return (MLGetMint(loopbackLink_, &i) == 0) ? 0 : i;
}

double MLExpr::asDouble() const
{
	MLAutoMark mark(loopbackLink_, true);
	double d;
	return (MLGetDouble(loopbackLink_, &d) == 0) ? 0. : d;
}

const char* MLExpr::asString() const
{
	int unused;
	if (!str_)
	{
		MLAutoMark mark(loopbackLink_, true);
		MLGetUTF8String(loopbackLink_, (const unsigned char**) &str_, &len_, &unused);
	}
	return str_;
}

const git_oid* MLExpr::asOid() const
{
	static git_oid oid;
	const char* str;
	if (!str_ && isString())
		asString();
	if (!str_ && testHead("GitObject") && part(1).isString())
	{
		MLAutoMark mark(loopbackLink_, true);
		int argCount;
		int unused;
		MLTestHead(loopbackLink_, "GitObject", &argCount);
		MLGetUTF8String(loopbackLink_, (const unsigned char**) &str_, &len_, &unused);
	}
	return (str_ != NULL && git_oid_fromstr(&oid, str_) == 0) ? &oid : NULL;
}

int MLExpr::length() const
{
	if (loopbackLink_ == NULL)
		return 0;
	MLAutoMark mark(loopbackLink_, true);
	int len;
	MLGetNext(loopbackLink_);
	MLGetArgCount(loopbackLink_, &len);
	return len;
}

bool MLExpr::isInteger() const
{
	if (loopbackLink_ == NULL)
		return false;
	MLAutoMark mark(loopbackLink_, true);
	return (MLGetNext(loopbackLink_) == MLTKINT);
}

bool MLExpr::isReal() const
{
	if (loopbackLink_ == NULL)
		return false;
	MLAutoMark mark(loopbackLink_, true);
	return (MLGetNext(loopbackLink_) == MLTKREAL);
}

bool MLExpr::isSymbol() const
{
	if (loopbackLink_ == NULL)
		return false;
	MLAutoMark mark(loopbackLink_, true);
	return (MLGetNext(loopbackLink_) == MLTKSYM);
}

bool MLExpr::isString() const
{
	if (loopbackLink_ == NULL)
		return false;
	MLAutoMark mark(loopbackLink_, true);
	return (MLGetNext(loopbackLink_) == MLTKSTR);
}

bool MLExpr::isFunction() const
{
	if (loopbackLink_ == NULL)
		return false;
	MLAutoMark mark(loopbackLink_, true);
	return (MLGetNext(loopbackLink_) == MLTKFUNC);
}

bool MLExpr::contains(const char* str) const
{
	if (isString())
		return testString(str);
	if (isSymbol())
		return testSymbol(str);
	if (isFunction())
	{
		for (int i = 1; i <= length(); i++)
			if (part(i).contains(str))
				return true;
	}
	return false;
}

MLExpr MLExpr::lookupKey(const char* str) const
{
	if (!testHead("Association"))
		return MLExpr(NULL);
	for (int i = 1; i <= length(); i++)
	{
		if (!part(i).isRule())
			continue;
		if (part(i).part(1).testString(str))
			return part(i).part(2);
	}
	return MLExpr(NULL);
}
