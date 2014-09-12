#ifndef GitLinkCommit_h_
#define GitLinkCommit_h_ 1

class GitLinkCommit
{
public:
//	GitLinkCommit(WolframLibraryData libData, mint Argc, MArgument* Argv, int repoArg = 0);
	GitLinkCommit(const GitLinkRepository& repo, MLINK link);
	GitLinkCommit(const GitLinkRepository& repo, git_index* index, GitLinkCommit& parent,
					const char* ref, const git_signature* author, const char* message);
	~GitLinkCommit();

	void writeSHA(MLINK link) const;

	void writeProperties(MLINK link);

	bool isValid() const { return valid_; };

	bool isHidden() const { return notSpec_; };

	const git_oid* oid() const { return &oid_; };

	int parentCount();

	git_commit* commit();

	const git_signature* author() { return isValid() ? git_commit_author(commit()) : NULL; };

	const char* message() { return isValid() ? git_commit_message(commit()) : NULL; };

	void mlWriteMessagePacket(WolframLibraryData libData, MLINK lnk, const char* functionName);

private:
	const GitLinkRepository& repo_;
	git_oid oid_;
	bool valid_;
	bool notSpec_;
	git_commit* commit_;
	const char* errCode_;
};

#endif // GitLinkCommit_h_
