#ifndef GitTree_h_
#define GitTree_h_ 1

#include <unordered_set>

typedef std::unordered_set<std::string> PathSet;

class GitTree : public GitLinkSuperClass
{
public:
	GitTree(const GitLinkRepository& repo, git_index* index);
	GitTree(const GitLinkRepository& repo, const char* reference);
	GitTree(const MLExpr& expr);
	GitTree(MLINK lnk)
		: GitTree(MLExpr(lnk))
	{ };

	virtual ~GitTree();

	void write(MLINK lnk) const;
	void writeContents(MLINK lnk, int depth) const;

	PathSet getDiffPaths(const GitTree& theirTree) const;

	int resetIndexToTreeEntry(git_index* index, const char* filename) const;

	bool isValid() const { return tree_ != NULL; };
	const git_oid* oid() const { return &oid_; };
	operator const git_tree*() const {return tree_; };
	operator const git_object*() const {return (const git_object*) tree_; };

private:
	const GitLinkRepository repo_;
	git_tree* tree_ = NULL;
	git_oid oid_;
	mutable MLHelper* helper_ = NULL; // used for callbacks
	mutable int depth_ = 1; // used for callbacks
	mutable std::string root_;

	static int writeTreeEntry_(const char* root, const git_tree_entry* entry, void* payload);
	static int addTreeEntryToMap_(const char* root, const git_tree_entry* entry, void* payload);
};

#endif // GitTree_h_
