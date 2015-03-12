#ifndef GitTree_h_
#define GitTree_h_ 1

class GitBlob : public GitLinkSuperClass
{
public:
	GitBlob(const MLExpr& expr);
	GitBlob(MLINK lnk)
		: GitBlob(MLExpr(lnk))
	{ };
	GitBlob(const GitLinkRepository& repo, MLINK lnk, const char* format);

	virtual ~GitBlob();

	void write(MLINK lnk) const;
	void writeContents(MLINK lnk, const char* format) const;

	bool isValid() const { return blob_ != NULL; };
	const git_oid* oid() const { return &oid_; };
	operator const git_blob*() const {return blob_; };
	operator const git_object*() const {return (const git_object*) blob_; };

private:
	const GitLinkRepository repo_;
	git_blob* blob_ = NULL;
	git_oid oid_;

};

#endif // GitTree_h_
