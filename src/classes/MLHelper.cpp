#include "mathlink.h"
#include "git2.h"
#include "WolframLibrary.h"
#include "MLHelper.h"
#include "GitLinkRepository.h"
#include <ctime>

MLHelper::MLHelper(MLINK lnk) :
	lnk_(lnk), unfinishedRule_(false)
{
	tmpLinks_.push_front(lnk);
	argCounts_.push_front(0);
	unfinishedRule_.push_front(false);
}

MLHelper::~MLHelper()
{
	while (tmpLinks_.front() != lnk_)
		endFunction();
}

void MLHelper::beginFunction(const char* head)
{
	int err;
	tmpLinks_.push_front(MLLoopbackOpen(MLLinkEnvironment(lnk_), &err));
	argCounts_.push_front(0);
	unfinishedRule_.push_front(false);
	MLPutSymbol(tmpLinks_.front(), head);
}

void MLHelper::endFunction()
{
	MLINK loopbackLink = tmpLinks_.front();
	int argCount = argCounts_.front();
	tmpLinks_.pop_front();
	argCounts_.pop_front();
	unfinishedRule_.pop_front();

	MLINK destLink = tmpLinks_.front();
	MLPutNext(destLink, MLTKFUNC);
	MLPutArgCount(destLink, argCount);
	MLTransferExpression(destLink, loopbackLink);
	for (int i = 0; i < argCount; i++)
		MLTransferExpression(destLink, loopbackLink);
	MLClose(loopbackLink);
	incrementArgumentCount_();
}

void MLHelper::putString(const char* value)
{
	MLPutString(tmpLinks_.front(), value);
	incrementArgumentCount_();
}

void MLHelper::putSymbol(const char* value)
{
	MLPutString(tmpLinks_.front(), value);
	incrementArgumentCount_();
}

void MLHelper::putOid(const git_oid& value)
{
	char buf[GIT_OID_HEXSZ + 1];
	git_oid_tostr(buf, GIT_OID_HEXSZ + 1, &value);
	MLPutString(tmpLinks_.front(), buf);
	incrementArgumentCount_();
}

void MLHelper::putRepo(const GitLinkRepository& repo)
{
	MLINK lnk = tmpLinks_.front();
	MLPutFunction(lnk, "GitRepo", 1);
	MLPutInteger(lnk, repo.key());
	argCounts_.front()++;
}


void MLHelper::putRule(const char* key)
{
	MLINK lnk = tmpLinks_.front();
	MLPutFunction(lnk, "Rule", 2);
	MLPutString(lnk, key);
	argCounts_.front()++;
	unfinishedRule_.front() = true;
}

void MLHelper::putRule(const char* key, int value)
{
	MLINK lnk = tmpLinks_.front();
	MLPutFunction(lnk, "Rule", 2);
	MLPutString(lnk, key);
	MLPutSymbol(lnk, value ? "True" : "False");
	argCounts_.front()++;
}

void MLHelper::putRule(const char* key, double value)
{
	MLINK lnk = tmpLinks_.front();
	MLPutFunction(lnk, "Rule", 2);
	MLPutString(lnk, key);
	MLPutDouble(lnk, value);
	argCounts_.front()++;
}

void MLHelper::putRule(const char* key, const git_time& value)
{
	struct tm* tmPtr = localtime((time_t*)&value.time);
	MLINK lnk = tmpLinks_.front();
	MLPutFunction(lnk, "Rule", 2);
	MLPutString(lnk, key);
	MLPutFunction(lnk, "DateObject", 2);
	MLPutFunction(lnk, "List", 6);
	MLPutInteger(lnk, tmPtr->tm_year + 1900);
	MLPutInteger(lnk, tmPtr->tm_mon + 1);
	MLPutInteger(lnk, tmPtr->tm_mday);
	MLPutInteger(lnk, tmPtr->tm_hour);
	MLPutInteger(lnk, tmPtr->tm_min);
	MLPutInteger(lnk, tmPtr->tm_sec);
	MLPutFunction(lnk, "Rule", 2);
	MLPutSymbol(lnk, "TimeZone");
	MLPutReal(lnk, (double)value.offset / 60.);
	argCounts_.front()++;
}

void MLHelper::putRule(const char* key, const char* value)
{
	MLINK lnk = tmpLinks_.front();
	MLPutFunction(lnk, "Rule", 2);
	MLPutUTF8String(lnk, (const unsigned char*)key, (int)strlen(key));
	if (value == NULL)
		MLPutSymbol(lnk, "$Failed");
	else
		MLPutUTF8String(lnk, (const unsigned char*)value, (int)strlen(value));
	argCounts_.front()++;
}

void MLHelper::putRule(const char* key, const git_oid& value)
{
	putRule(key);
	putOid(value);
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
	argCounts_.front()++;
}

void MLHelper::putRule(const char* key, git_status_list* list, git_status_t status)
{
	putRule(key);
	beginList();
	for (int i = 0; i < git_status_list_entrycount(list); i++)
	{
		const git_status_entry* entry = git_status_byindex(list, i);
		if ((entry->status & status) != 0)
		{
			const git_diff_delta* diffDelta = (status < GIT_STATUS_WT_NEW) ? entry->head_to_index : entry->index_to_workdir;
			if (status == GIT_STATUS_INDEX_RENAMED || status == GIT_STATUS_WT_RENAMED)
				putRule(diffDelta->old_file.path, diffDelta->new_file.path);
			else if (status == GIT_STATUS_INDEX_DELETED || status == GIT_STATUS_WT_DELETED)
				putString(diffDelta->old_file.path);
			else
				putString(diffDelta->new_file.path);
		}
	}
	endList();
}

std::string MLGetCPPString(MLINK lnk)
{
	const unsigned char* bytes;
	std::string str;
	int len, unused;
	MLGetUTF8String(lnk, &bytes, &len, &unused);
	str.assign((const char*) bytes, len);
	MLReleaseUTF8String(lnk, bytes, len);
	return str;
}

void MLHandleError(WolframLibraryData libData, const char* functionName, const char* messageName, const char* param)
{
	if (messageName == NULL)
		return;

	MLINK lnk = libData->getMathLink(libData);
	MLPutFunction(lnk, "EvaluatePacket", 1);
	MLPutFunction(lnk, "Message", (param == NULL) ? 1 : 2);
	MLPutFunction(lnk, "MessageName", 2);
	MLPutSymbol(lnk, functionName);
	MLPutString(lnk, messageName);
	if (param)
		MLPutString(lnk, param);
	libData->processWSLINK(lnk);
	int pkt = MLNextPacket(lnk);
	if ( pkt == RETURNPKT)
		MLNewPacket(lnk);
}

