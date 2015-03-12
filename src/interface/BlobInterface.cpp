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
#include "RepoInterface.h"
#include "GitLinkRepository.h"
#include "GitBlob.h"
#include "Message.h"
#include <climits>


EXTERN_C DLLEXPORT int GitReadBlob(WolframLibraryData libData, MLINK lnk)
{
	long argCount;
	MLCheckFunction(lnk, "List", &argCount);

	MLString format(lnk);
	GitBlob blob(lnk);
	MLExpr pathNameHint(lnk); // to be implemented

	if (blob.isValid())
		blob.writeContents(lnk, format);
	else
	{
		blob.mlHandleError(libData, "GitReadBlob");
		MLPutSymbol(lnk, "$Failed");
	}

	return LIBRARY_NO_ERROR;
}

EXTERN_C DLLEXPORT int GitWriteBlob(WolframLibraryData libData, MLINK lnk)
{
	bool success = false;
	long argCount;
	MLCheckFunction(lnk, "List", &argCount);
	GitLinkRepository repo(lnk);
	MLString format(lnk);
	MLExpr pathNameHint(lnk); // to be implemented
	GitBlob blob(repo, lnk, format);

	if (blob.isValid())
		blob.write(lnk);
	else
	{
		blob.mlHandleError(libData, "GitWriteBlob");
		MLPutSymbol(lnk, "$Failed");
	}
	return LIBRARY_NO_ERROR;
}
