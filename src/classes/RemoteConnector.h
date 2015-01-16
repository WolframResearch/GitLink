#ifndef RemoteConnector_h_
#define RemoteConnector_h_ 1

#include <chrono>

#include "git2.h"
#include "WolframLibrary.h"
#include "MLExpr.h"

/// Manages all of the connectors in libgit2, including all of the callbacks.
class RemoteConnector
{
public:
	RemoteConnector();
	RemoteConnector(WolframLibraryData libData, const char* theKeyFile);
	RemoteConnector(WolframLibraryData libData, const RemoteConnector& connector)
		: RemoteConnector(libData, connector.keyFile_)
	{ };
	~RemoteConnector();
	RemoteConnector& operator=(const RemoteConnector& connector);

	const char* keyFile() const { return keyFile_; };

	bool fetch(git_remote* remote) { return connect_(remote, GIT_DIRECTION_FETCH); };
	bool push(git_remote* remote) { return connect_(remote, GIT_DIRECTION_PUSH); };
	bool clone(git_repository** repo, const char* uri, const char* localPath, git_clone_options* options, const MLExpr& progressFunction);

private:
	static int AcquireCredsCallback(git_cred** cred,const char* url,const char *username,unsigned int allowed_types, void* payload);
	int acquireCredsCallback_(git_cred** cred, const char* url, const char* username, unsigned int allowed_types);

	static int TransferProgressCallback(const git_transfer_progress* stats, void* payload);
	static int SidebandProgressCallback(const char* str, int len, void* payload);
	bool connect_(git_remote* remote, git_direction direction);

	WolframLibraryData libData_ = NULL;
	bool checkForSshAgent_ = true;
	const char* keyFile_;
	git_remote_callbacks callbacks_;
	MLExpr progressFunction_;
	std::chrono::steady_clock::time_point lastProgressCheckpoint_ = std::chrono::steady_clock::now();
};

#endif // RemoteConnector_h_
