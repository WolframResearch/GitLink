#ifndef MergeFactory_h_
#define MergeFactory_h_ 1

#include "GitLinkRepository.h"
#include <deque>

enum MergeFactoryMergeType
{
	eMergeTypeMerge,
	eMergeTypeRebase,
	eMergeTypeCherryPick
};

class MergeFactory : GitLinkSuperClass()
{
public:
	MergeFactory(MLExpr& argv)
		: repo_(argv.part(1))
		, argv_(argv)
		, isValid_(false)
	{ };

	/// this validates argv, and it can fail.
	bool initialize(MergeFactoryMergeType mergeType);

	virtual void mlHandleError(WolframLibraryData libData, const char* functionName);

private:
	MLExpr argv_;
	GitRepository repo_;
	bool isValid_;
	std::deque<GitLinkCommit> mergeSources_;
	GitLinkCommit dest_;
};


#endif // MergeFactory_h_
