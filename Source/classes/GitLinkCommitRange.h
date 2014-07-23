#ifndef GitLinkCommitRange_h_
#define GitLinkCommitRange_h_ 1

class GitLinkCommitRange
{
public:
	GitLinkCommitRange(const GitLinkRepository& repo);
	~GitLinkCommitRange();

	void buildRange(MLINK lnk, long argCount);

	/// Resets walker once called
	void writeRange(MLINK lnk);

	void addCommitSpecToRange(const GitLinkCommit& commit);

	bool isValid() const { return commitsValid_ && revPushed_; };

private:
	const GitLinkRepository& repo_;
	git_revwalk* revWalker_;
	bool commitsValid_;
	bool revPushed_;
};

#endif // GitLinkCommitRange_h_
