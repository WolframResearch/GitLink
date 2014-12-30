#ifndef Signature_h_
#define Signature_h_ 1

class GitLinkRepository;
class MLExpr;

#include "MLHelper.h"
#include "MLExpr.h"

class Signature
{
public:
	Signature();
	Signature(const Signature& signature);
	Signature(const GitLinkRepository& repo);
	Signature(const MLExpr& expr);
	Signature(const GitLinkRepository& repo, const MLExpr& expr);
	Signature(const GitLinkRepository& repo, MLINK lnk)
		: Signature(repo, MLExpr(lnk))
	{ };
	Signature(const git_signature* signature);
	~Signature() { if (sig_) git_signature_free((git_signature*)sig_); };

	Signature& operator=(const Signature& signature);
	operator const git_signature*() const { return sig_; }; 

	void writeAssociation(MLINK lnk) const;
	void writeAssociation(MLHelper& helper) const;

private:
	git_signature* sig_ = NULL;
};

#endif // Signature_h_
