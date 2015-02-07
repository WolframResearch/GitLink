#ifndef CheckoutManager_h_
#define CheckoutManager_h_ 1

#include "GitTree.h"

class CheckoutManager : public GitLinkSuperClass
{
public:
	CheckoutManager(GitLinkRepository& repo);

	bool initCheckout(WolframLibraryData libData, const char* ref);
	bool doCheckout();

private:
	PathSet refChangedFiles_;
	std::string ref_;
	GitLinkRepository& repo_;

	void populatePaths_(git_strarray* strarray) const;
	void freePaths_(git_strarray* strarray) const;

};

#endif // CheckoutManager_h_
