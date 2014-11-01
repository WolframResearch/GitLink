#ifndef GitLinkCommit_h_
#define GitLinkCommit_h_ 1

#include "GitLinkSuperClass.h"

class GitLinkCommit : public GitLinkSuperClass
{
public:
//	GitLinkCommit(WolframLibraryData libData, mint Argc, MArgument* Argv, int repoArg = 0);
	GitLinkCommit(const GitLinkRepository& repo, MLINK link);
	GitLinkCommit(const GitLinkRepository& repo, git_index* index, GitLinkCommit& parent,
					const git_signature* author, const char* message);
	~GitLinkCommit();

	void writeSHA(MLINK link) const;

	void writeProperties(MLINK link);

	bool isValid() const { return valid_; };

	bool isHidden() const { return notSpec_; };

	const git_oid* oid() const { return &oid_; };

	int parentCount();

	git_commit* commit();

	bool createBranch(const char* branchName, bool force);

	const git_signature* author() { return isValid() ? git_commit_author(commit()) : NULL; };

	const git_signature* committer() { return isValid() ? git_commit_committer(commit()) : NULL; };

	const char* message() { return isValid() ? git_commit_message(commit()) : NULL; };

private:
	const GitLinkRepository& repo_;
	git_oid oid_;
	bool valid_;
	bool notSpec_;
	git_commit* commit_;
};

#endif // GitLinkCommit_h_
