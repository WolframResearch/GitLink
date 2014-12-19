#ifndef Signature_h_
#define Signature_h_ 1

class GitLinkRepository;
class MLExpr;

#include "MLHelper.h"

class Signature
{
public:
	Signature();
	Signature(const Signature& signature);
	Signature(const GitLinkRepository& repo);
	Signature(MLExpr& expr);
	Signature(const git_signature* signature);
	~Signature() { if (sig_) git_signature_free((git_signature*)sig_); };

	Signature& Signature::operator=(const Signature& signature);
	operator const git_signature*() const { return sig_; }; 

	void writeAssociation(MLINK lnk) { writeAssociation(MLHelper(lnk)); };
	void writeAssociation(MLHelper& helper);

private:
	git_signature* sig_;
};

#endif // Signature_h_
