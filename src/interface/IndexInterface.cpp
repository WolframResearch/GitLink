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
#include "GitTree.h"
#include "Message.h"
#include "RepoStatus.h"
#include "Signature.h"


EXTERN_C DLLEXPORT int GitAddRemovePath(WolframLibraryData libData, MLINK lnk)
{
	long argCount;
	MLCheckFunction(lnk, "List", &argCount);

	GitLinkRepository repo(lnk);
	MLString pathArg(lnk);
	MLString command(lnk);
	MLExpr force(lnk);

	PathString path(pathArg);

	MLExpr returnList(MLLinkEnvironment(lnk), MLExpr::eConstructEmptyFunction, "List");

	if (repo.isValid())
	{
		FileNameSet candidateFilenames = RepoStatus(repo, false, force.asBool()).allFileNames();
		std::deque<std::string> actualFilenames = candidateFilenames.getPathSpecMatches(path);

		int result = 0;
		const char* errCode = Message::GitOperationFailed;
		const GitTree tree(repo, "HEAD");
		git_index* index;
		git_repository_index(&index, repo.repo());

		giterr_clear();
		for (const auto& it : actualFilenames)
		{
			if (strcmp(command, "GitAdd") == 0)
			{
				result = git_index_add_bypath(index, it.c_str());
				if (result == GIT_ENOTFOUND)
				{
					giterr_clear();
					result = git_index_remove_bypath(index, it.c_str());
				}
			}
			else if (strcmp(command, "GitReset") == 0)
				result = tree.resetIndexToTreeEntry(index, it.c_str());
			else
			{
				result = -1;
				errCode = Message::InvalidArguments;
				giterr_clear();
			}
			if (result == 0)
				returnList.append(MLExpr(MLLinkEnvironment(lnk), MLExpr::eConstructString, PathString(it)));
		}

		if (result == 0)
		{
			errCode = Message::CantWriteIndex;
			result = git_index_write(index);
		}
		git_index_free(index);

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
