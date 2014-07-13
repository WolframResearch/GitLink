#include "mathlink.h"
#include "git2.h"
#include "MLHelper.h"

void MLHelper::beginFunction(const char* head)
{
	tmpLinks_.push_front(MLLoopbackOpen(NULL, NULL));
	argCounts_.push_front(0);
	MLPutSymbol(tmpLinks_.front(), head);
}

void MLHelper::endFunction()
{
	MLINK loopbackLink = tmpLinks_.front();
	int argCount = argCounts_.front();
	tmpLinks_.pop_front();
	argCounts_.pop_front();

	MLINK destLink = tmpLinks_.empty() ? lnk_ : tmpLinks_.front();
	MLPutNext(destLink, MLTKFUNC);
	MLPutArgCount(destLink, argCount);
	MLTransferExpression(destLink, loopbackLink);
	for (int i = 0; i < argCount; i++)
		MLTransferExpression(destLink, loopbackLink);
	MLClose(loopbackLink);
}

void MLHelper::putString(const char* value)
{
	MLPutString(tmpLinks_.front(), value);
	
}

void MLHelper::putSymbol(const char* value)
{
	MLPutString(tmpLinks_.front(), value);
	
}



void MLHelper::putRule(const char* key, int value)
{
	MLINK lnk = tmpLinks_.front();
	MLPutFunction(lnk, "Rule", 2);
	MLPutString(lnk, key);
	MLPutSymbol(lnk, value ? "True" : "False");
}

void MLHelper::putRule(const char* key, const char* value)
{
	MLINK lnk = tmpLinks_.front();
	MLPutFunction(lnk, "Rule", 2);
	MLPutString(lnk, key);
	if (value == NULL)
		MLPutSymbol(lnk, "$Failed");
	else
		MLPutUTF8String(lnk, (const unsigned char*)value, (int)strlen(value));
}

void MLHelper::putRule(const char* key, git_repository_state_t value)
{
	MLINK lnk = tmpLinks_.front();
	MLPutFunction(lnk, "Rule", 2);
	MLPutString(lnk, key);

	const char* state;
	switch (value)
	{
		case GIT_REPOSITORY_STATE_MERGE:
			state = "Merge";
			break;
		case GIT_REPOSITORY_STATE_REVERT:
			state = "Revert";
			break;
		case GIT_REPOSITORY_STATE_CHERRY_PICK:
			state = "CherryPick";
			break;
		case GIT_REPOSITORY_STATE_BISECT:
			state = "Bisect";
			break;
		case GIT_REPOSITORY_STATE_REBASE:
			state = "Rebase";
			break;
		case GIT_REPOSITORY_STATE_REBASE_INTERACTIVE:
			state = "RebaseInteractive";
			break;
		case GIT_REPOSITORY_STATE_REBASE_MERGE:
			state = "RebaseMerge";
			break;
		case GIT_REPOSITORY_STATE_APPLY_MAILBOX:
			state = "ApplyMailbox";
			break;
		case GIT_REPOSITORY_STATE_APPLY_MAILBOX_OR_REBASE:
			state = "ApplyMailboxOrRebase";
			break;
		default:
			state = "None";
			break;
	}
	MLPutString(lnk, state);
}

