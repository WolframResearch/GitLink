#ifndef GitLinkCommit_h_
#define GitLinkCommit_h_ 1

class GitLinkCommit
{
public:
//	GitLinkCommit(WolframLibraryData libData, mint Argc, MArgument* Argv, int repoArg = 0);
	GitLinkCommit(GitLinkRepository& repo, MLINK link);
//	~GitLinkCommit();

	void writeSHA(MLINK link);

	bool isValid() { return valid_; };

private:
	GitLinkRepository& repo_;
	git_oid oid_;
	bool valid_;
	bool notSpec_;
};

#endif // GitLinkCommit_h_
