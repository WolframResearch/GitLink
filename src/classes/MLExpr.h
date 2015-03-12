#ifndef MLExpr_h_
#define MLExpr_h_ 1

#include "WolframLibrary.h"

typedef struct git_oid git_oid;

class MLExpr
{
public:
	MLExpr() : loopbackLink_(NULL), str_(NULL), len_(0) { };
	MLExpr(MLINK lnk);
	MLExpr(const MLExpr& expr);
	MLExpr(MLExpr&& expr);
	~MLExpr() { if (str_) MLReleaseUTF8String(loopbackLink_, (const unsigned char*) str_, len_); MLClose(loopbackLink_); };
	MLExpr& operator=(const MLExpr& expr);
	MLExpr& operator=(MLExpr&& expr);

	MLINK initializeLink(MLEnvironment env);
	
	void putToLink(MLINK lnk) const;
	MLINK putToLoopbackLink() const;
	bool testString(const char* str) const;
	bool testSymbol(const char* sym) const;
	bool testHead(const char* sym) const;
	int asInt() const;
	mint asMint() const;
	double asDouble() const;
	// warning...the returned string only lives as long as the MLExpr does.  So, e.g.,
	// calling expr.part(1).asString() would be a bad idea.
	const char* asString() const;
	const git_oid* asOid() const;
	MLExpr part(int i) const;
	MLExpr part(int i, int j) const { return part(i).part(j); };
	int length() const;
	int partLength(int i) const { return part(i).length(); };
	bool isNull() const { return loopbackLink_ == NULL; };
	bool isInteger() const;
	bool isReal() const;
	bool isSymbol() const;
	bool isString() const;
	bool isFunction() const;
	bool isList() const { return testHead("List"); };
	bool isRule() const { return (length() == 2 && (testHead("Rule") || testHead("RuleDelayed"))); };

	// returns matches on both strings or symbols, and doesn't check heads
	bool contains(const char* str) const;

	// for an Expr of head Association, looks up the key 'str'
	bool containsKey(const char* str) const { return !lookupKey(str).isNull(); };
	MLExpr lookupKey(const char* str) const;

private:
	mutable MLINK loopbackLink_;
	mutable const char* str_;
	mutable int len_;
};


#endif // MLExpr_h_
