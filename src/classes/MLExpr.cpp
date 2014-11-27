#include "mathlink.h"
#include "MLExpr.h"
#include "git2.h"
#include "WolframLibrary.h"
#include "MLHelper.h"

MLExpr::MLExpr(MLINK lnk)
	: str_(NULL)
	, len_(0)
{
	int err;
	loopbackLink_ = MLLoopbackOpen(MLLinkEnvironment(lnk), &err);
	MLTransferExpression(loopbackLink_, lnk);
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

bool MLExpr::testSymbol(const char* sym) const
{
	MLAutoMark mark(loopbackLink_, true);
	if (MLGetNext(loopbackLink_) == MLTKSYM)
	{
		MLString str(loopbackLink_);
		return (strcmp(str, sym) == 0);
	}
	return false;
}

bool MLExpr::testHead(const char* sym) const
{
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

int MLExpr::getInt() const
{
	MLAutoMark mark(loopbackLink_, true);
	int i;
	return (MLGetInteger(loopbackLink_, &i) == 0) ? 0 : i;
}

mint MLExpr::getMint() const
{
	MLAutoMark mark(loopbackLink_, true);
	mint i;
#if SIXTYFOURBIT
	return (MLGetInteger64(loopbackLink_, &i) == 0) ? 0 : i;
#else
	return (MLGetInteger(loopbackLink_, &i) == 0) ? 0 : i;
#endif
}

int MLExpr::length() const
{
	MLAutoMark mark(loopbackLink_, true);
	int len;
	MLGetNext(loopbackLink_);
	MLGetArgCount(loopbackLink_, &len);
	return len;
}

bool MLExpr::isInteger() const
{
	MLAutoMark mark(loopbackLink_, true);
	return (MLGetNext(loopbackLink_) == MLTKINT);
}

bool MLExpr::isSymbol() const
{
	MLAutoMark mark(loopbackLink_, true);
	return (MLGetNext(loopbackLink_) == MLTKSYM);
}

bool MLExpr::isString() const
{
	MLAutoMark mark(loopbackLink_, true);
	return (MLGetNext(loopbackLink_) == MLTKSTR);
}

bool MLExpr::isFunction() const
{
	MLAutoMark mark(loopbackLink_, true);
	return (MLGetNext(loopbackLink_) == MLTKFUNC);
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
