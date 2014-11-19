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
		: repo_(GitLinkRepository(argv.part(1)))
		, argv_(argv)
		, isValid_(false)
		, dest_(NULL)
	{ };

	~MergeFactory()
	{ delete dest_; };

	/// this validates argv, and it can fail.
	bool initialize(MergeFactoryMergeType mergeType);

	virtual void mlHandleError(WolframLibraryData libData, const char* functionName) const;

	void writeSHAOrFailure(MLINK lnk);

	void doMerge();

private:
	const MLExpr argv_;
	const GitLinkRepository repo_;
	bool isValid_;
	std::deque<GitLinkCommit> mergeSources_;
	GitLinkCommit* dest_;
};


#endif // MergeFactory_h_
