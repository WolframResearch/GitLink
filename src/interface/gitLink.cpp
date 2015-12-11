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
#include "MLExpr.h"
#include "MLHelper.h"
#include "RepoInterface.h"

#include <sstream>


/* Return the version of Library Link */
EXTERN_C DLLEXPORT mint WolframLibrary_getVersion()
{
	return WolframLibraryVersion;
}

/* Initialize Library */
EXTERN_C DLLEXPORT int WolframLibrary_initialize(WolframLibraryData libData)
{
	git_libgit2_init();
	return 0;
}

/* Uninitialize Library */
EXTERN_C DLLEXPORT void WolframLibrary_uninitialize(WolframLibraryData libData)
{
	git_libgit2_shutdown();
}

EXTERN_C DLLEXPORT int GitLibraryInformation(WolframLibraryData libData, MLINK lnk)
{
	MLExpr dummy(lnk);
	MLHelper helper(lnk);

	helper.beginFunction("Association");

	// Versioning
	int major, minor, rev;
	git_libgit2_version(&major, &minor, &rev);
	std::ostringstream verString;
	verString << major << "." << minor << "." << rev;
	double versionNumber = minor;
	while (versionNumber > 1) versionNumber /= 10.;
	versionNumber += major;

	helper.putRule("VersionString", verString.str());
	helper.putRule("VersionNumber", versionNumber);
	helper.putRule("ReleaseNumber"); helper.putMint(rev);

	// Features
	int features = git_libgit2_features();
	helper.putRule("Features");
	helper.beginList();
	if ((features & GIT_FEATURE_THREADS) != 0)
		helper.putString("Threads");
	if ((features & GIT_FEATURE_HTTPS) != 0)
		helper.putString("Https");
	if ((features & GIT_FEATURE_SSH) != 0)
		helper.putString("Ssh");
	helper.endList();

	// Options
	size_t size, size2;
	git_libgit2_opts(GIT_OPT_GET_MWINDOW_SIZE, &size);
	helper.putRule("MemoryMapWindowSizeLimit"); helper.putMint(size);

	git_libgit2_opts(GIT_OPT_GET_MWINDOW_MAPPED_LIMIT, &size);
	helper.putRule("MemoryMapTotalLimit"); helper.putMint(size);

	git_buf buf = GIT_BUF_INIT_CONST(NULL, 0);
	git_libgit2_opts(GIT_OPT_GET_SEARCH_PATH, GIT_CONFIG_LEVEL_SYSTEM, &buf);
	helper.putRule("SystemConfigSearchPath", buf.ptr);
	git_buf_free(&buf);

	buf = GIT_BUF_INIT_CONST(NULL, 0);
	git_libgit2_opts(GIT_OPT_GET_SEARCH_PATH, GIT_CONFIG_LEVEL_GLOBAL, &buf);
	helper.putRule("GlobalConfigSearchPath", buf.ptr);
	git_buf_free(&buf);

	buf = GIT_BUF_INIT_CONST(NULL, 0);
	git_libgit2_opts(GIT_OPT_GET_SEARCH_PATH, GIT_CONFIG_LEVEL_XDG, &buf);
	helper.putRule("XdgConfigSearchPath", buf.ptr);
	git_buf_free(&buf);

	git_libgit2_opts(GIT_OPT_GET_CACHED_MEMORY, &size, &size2);
	helper.putRule("MemoryCacheInUse"); helper.putMint(size);
	helper.putRule("MemoryCacheLimit"); helper.putMint(size2);

	buf = GIT_BUF_INIT_CONST(NULL, 0);
	git_libgit2_opts(GIT_OPT_GET_TEMPLATE_PATH, &buf);
	helper.putRule("DefaultTemplatePath", buf.ptr);
	git_buf_free(&buf);

	helper.endFunction();

	return LIBRARY_NO_ERROR;
}

