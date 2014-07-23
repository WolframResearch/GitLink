#ifndef GitLinkCommit_h_
#define GitLinkCommit_h_ 1

class GitLinkCommit
{
public:
//	GitLinkCommit(WolframLibraryData libData, mint Argc, MArgument* Argv, int repoArg = 0);
	GitLinkCommit(const GitLinkRepository& repo, MLINK link);
//	~GitLinkCommit();

	void writeSHA(MLINK link) const;

	void writeProperties(MLINK link) const;

	bool isValid() const { return valid_; };

	bool isHidden() const { return notSpec_; };

	const git_oid* oid() const { return &oid_; };

private:
	const GitLinkRepository& repo_;
	git_oid oid_;
	bool valid_;
	bool notSpec_;
};

#endif // GitLinkCommit_h_
