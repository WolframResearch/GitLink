#ifndef CheckoutManager_h_
#define CheckoutManager_h_ 1

class CheckoutManager
{
public:
	CheckoutManager(GitLinkRepository& repo);

	bool checkoutScanForConflicts(const char* ref);

private:
	GitLinkRepository& repo_;
};

#endif // CheckoutManager_h_
