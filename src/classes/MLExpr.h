#ifndef MLExpr_h_
#define MLExpr_h_ 1

class MLExpr
{
public:
	MLExpr(MLINK lnk);
	MLExpr(const MLExpr& expr);
	~MLExpr() { if (str_) MLReleaseUTF8String(loopbackLink_, (const unsigned char*) str_, len_); MLClose(loopbackLink_); };
	MLExpr& operator=(const MLExpr& expr);

	void putToLink(MLINK lnk) const;
	MLINK putToLoopbackLink() const;
	bool testSymbol(const char* sym) const;
	bool testHead(const char* sym) const;
	int getInt() const;
	MLExpr part(int i) const;
	MLExpr part(int i, int j) const { return part(i).part(j); };
	int length() const;
	int partLength(int i) const { return part(i).length(); };
	bool isSymbol() const;
	bool isString() const;
	bool isFunction() const;
	bool isList() const { return testHead("List"); };
	const char* asString() const;

private:
	mutable MLINK loopbackLink_;
	mutable const char* str_;
	mutable int len_;
};


#endif // MLExpr_h_
