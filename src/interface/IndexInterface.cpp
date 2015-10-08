/*
 *  gitLink
 *
 *  Created by John Fultz on 6/18/14.
 *  Copyright (c) 2014 Wolfram Research. All rights reserved.
 *
 */

#include "mathlink.h"
#include "WolframLibrary.h"
#include "git2.h"
#include "GitLinkRepository.h"
#include "Message.h"
#include "Signature.h"

class GitPathCollector
{
public:
	GitPathCollector(GitLinkRepository& r, MLExpr& e, MLString& c) : expr(e), repo(r), command(c) { };

	GitLinkRepository& repo;
	MLExpr& expr;
	MLString& command;
};

static int collectPathNames(const char *path, const char *matched_pathspec, void *payload)
{
	GitPathCollector* collector = (GitPathCollector*) payload;
	const int SkipOperation = 1;
	const int ContinueOperation = 0;
	unsigned int status_flags;

	if (git_status_file(&status_flags, collector->repo.repo(), path) == 0)
	{
		const int addFlags = GIT_STATUS_WT_NEW | GIT_STATUS_WT_MODIFIED |
							GIT_STATUS_WT_DELETED | GIT_STATUS_WT_RENAMED |
							GIT_STATUS_WT_TYPECHANGE;
		const int resetFlags = GIT_STATUS_INDEX_NEW | GIT_STATUS_INDEX_MODIFIED |
							GIT_STATUS_INDEX_DELETED | GIT_STATUS_INDEX_RENAMED |
							GIT_STATUS_INDEX_TYPECHANGE;

		if (status_flags == GIT_STATUS_CURRENT)
			return SkipOperation;
		if (strcmp(collector->command, "GitAdd") == 0 && ((status_flags & addFlags) == 0))
			return SkipOperation;
		if (strcmp(collector->command, "GitReset") == 0 && ((status_flags & resetFlags) == 0))
			return SkipOperation;
	}

	collector->expr.append(MLExpr(collector->expr.mle(), MLExpr::eConstructString, path));
	return ContinueOperation;
}

EXTERN_C DLLEXPORT int GitAddRemovePath(WolframLibraryData libData, MLINK lnk)
{
	long argCount;
	MLCheckFunction(lnk, "List", &argCount);

	GitLinkRepository repo(lnk);
	MLString path(lnk);
	MLString command(lnk);
	MLExpr force(lnk);
	const char* pathStr = path;
	const git_strarray indexPaths{(char **)&pathStr, 1};

	MLExpr returnList(MLLinkEnvironment(lnk), MLExpr::eConstructEmptyFunction, "List");

	if (repo.isValid())
	{
		int result;
		const char* errCode = Message::GitOperationFailed;
		git_index_matched_path_cb callback = (git_index_matched_path_cb) collectPathNames;

		git_index* index;
		git_repository_index(&index, repo.repo());

		GitPathCollector pathCollector(repo, returnList, command);
		if (strcmp(command, "GitAdd") == 0)
		{
			result = git_index_add_all(index, &indexPaths, force.asBool() ? GIT_INDEX_ADD_FORCE : GIT_INDEX_ADD_DEFAULT,
										callback, (void*)&pathCollector);
		}
		else if (strcmp(command, "GitReset") == 0)
		{
			result = git_index_remove_all(index, &indexPaths, callback, (void*)&pathCollector);
		}
		else
		{
			result = -1;
			errCode = Message::InvalidArguments;
			giterr_clear();
		}

		if (result != 0)
		{
			const char* errParam = (giterr_last() == NULL) ? NULL : strdup(giterr_last()->message);
			MLHandleError(libData, command, errCode, errParam);
			free((void*)errParam);
		}
	}
	else
		repo.mlHandleError(libData, command);

	returnList.putToLink(lnk);
	return LIBRARY_NO_ERROR;
}
