#ifndef MLExpr_h_
#define MLExpr_h_ 1

class MLExpr
{
public:
	MLExpr(MLINK lnk);
	MLExpr(const MLExpr& expr);
	~MLExpr() { MLClose(loopbackLink_); };

	void putToLink(MLINK lnk) const;
	bool testSymbol(const char* sym) const;
	bool testHead(const char* sym) const;
	int getInt() const;
	MLExpr part(int i) const;

private:
	mutable MLINK loopbackLink_;

};


#endif // MLExpr_h_
