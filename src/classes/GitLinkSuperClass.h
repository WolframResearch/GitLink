#ifndef GitLinkSuperClass_h_
#define GitLinkSuperClass_h_ 1

#include "MLHelper.h"


class GitLinkSuperClass
{
public:
	GitLinkSuperClass() : errCode_(NULL), errCodeParam_(NULL) { };
	virtual ~GitLinkSuperClass() { };

	virtual void mlHandleError(WolframLibraryData libData, const char* functionName) const
	{
		MLHandleError(libData, functionName, errCode_, errCodeParam_);
	};

	void propagateError(GitLinkSuperClass& obj) { errCode_ = obj.errCode_; errCodeParam_ = obj.errCodeParam_; };

protected:
	const char* errCode_;
	const char* errCodeParam_;
};

#endif // GitLinkSuperClass_h_
