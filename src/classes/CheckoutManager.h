#ifndef CheckoutManager_h_
#define CheckoutManager_h_ 1

class CheckoutManager : public GitLinkSuperClass
{
public:
	CheckoutManager(GitLinkRepository& repo);

	bool initCheckout(const char* ref);
	void doCheckout();

private:
	GitLinkRepository& repo_;
};

#endif // CheckoutManager_h_
