#ifndef GitLinkCommit_h_
#define GitLinkCommit_h_ 1

#include "GitLinkSuperClass.h"
#include "MLExpr.h"
#include <vector>

class GitLinkCommitDeque;
class GitTree;

class GitLinkCommit : public GitLinkSuperClass
{
public:
	GitLinkCommit(const GitLinkRepository& repo, const MLExpr& expr);
	GitLinkCommit(const GitLinkRepository& repo, const char* refName);
	GitLinkCommit(const GitLinkRepository& repo, const git_oid* oid);
	GitLinkCommit(const GitLinkRepository& repo, MLINK link) : GitLinkCommit(repo, MLExpr(link)) { };
	GitLinkCommit(const GitLinkRepository& repo, const GitTree& tree, const GitLinkCommitDeque& parents,
					const git_signature* author, const git_signature* committer, const char* message);
	GitLinkCommit(const GitLinkCommit& commit);
	~GitLinkCommit();

	bool operator==(GitLinkCommit& c);

	void write(MLINK link) const;
	void writeSHA(MLINK link) const;

	void writeProperties(MLINK link);

	bool isValid() const { return valid_; };

	bool isHidden() const { return notSpec_; };

	const git_oid* oid() const { return &oid_; };

	int parentCount();

	git_commit* commit();

	git_object* object() { return (git_object*) commit(); };

	bool createBranch(const char* branchName, bool force);

	git_tree* copyTree();
	
	const git_signature* author() { return isValid() ? git_commit_author(commit()) : NULL; };

	const git_signature* committer() { return isValid() ? git_commit_committer(commit()) : NULL; };

	const char* message() { return isValid() ? git_commit_message(commit()) : NULL; };

private:
	const mint repoKey_; // we store the key rather than the repo for efficiency reasons
	git_oid oid_;
	bool valid_;
	bool notSpec_;
	git_commit* commit_;
};

class GitLinkCommitDeque : public std::deque<GitLinkCommit>, public GitLinkSuperClass
{
public:
	GitLinkCommitDeque();
	GitLinkCommitDeque(const GitLinkCommit& commit);
	GitLinkCommitDeque(const GitLinkRepository& repo, MLExpr expr);
	GitLinkCommitDeque& operator=(const GitLinkCommitDeque& theDeque);

	const git_commit** commits() const;
	bool isValid() const { return isValid_; };

private:
	bool isValid_;
	mutable std::vector<const git_commit*> commits_;
};

#endif // GitLinkCommit_h_
