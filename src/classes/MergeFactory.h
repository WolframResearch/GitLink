#ifndef MergeFactory_h_
#define MergeFactory_h_ 1

#include "GitLinkRepository.h"
#include "GitLinkCommit.h"
#include "MLExpr.h"
#include <deque>

enum MergeFactoryMergeType
{
	eMergeTypeMerge,
	eMergeTypeRebase,
	eMergeTypeCherryPick
};

class MergeFactory : public GitLinkSuperClass
{
public:
	MergeFactory(MLExpr& argv)
		: repo_(argv.part(1))
		, argv_(argv)
		, isValid_(false)
		, dest_(NULL)
		, resultSuccess_(false)
	{ };

	~MergeFactory()
	{ delete dest_; };

	/// this validates argv, and it can fail.
	bool initialize(MergeFactoryMergeType mergeType);

	virtual void mlHandleError(WolframLibraryData libData, const char* functionName) const;

	void write(MLINK lnk);

	void doMerge(WolframLibraryData libData);

	MLExpr handleConflicts(WolframLibraryData libData, git_index* index);


private:
	const MLExpr argv_;
	const GitLinkRepository repo_;
	bool isValid_;
	GitLinkCommitDeque mergeSources_;
	GitLinkCommitDeque strippedMergeSources_;
	GitLinkCommit* dest_;
	const char* commitLog_;
	std::string commitMessage_;
	MLExpr conflictFunctions_;
	MLExpr finalFunctions_;
	MLExpr progressFunction_;
	bool allowCommit_;
	bool allowFastForward_;
	bool allowIndexChanges_;

	bool resultSuccess_;
	git_oid resultOid_;
	const char* resultFailureType_;
	MLExpr resultFailureData_;

	// Builds strippedMergeSources_, which strips sources that can be fast-forwarded
	// to other sources
	bool buildStrippedMergeSources_();

	git_tree* ancestorCopyTree_();

	void putConflictData_(MLHelper& helper, const char* input,
			const git_index_entry* entry, bool withContents);
};


#endif // MergeFactory_h_
