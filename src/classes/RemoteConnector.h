#ifndef RemoteConnector_h_
#define RemoteConnector_h_ 1

#include <string>
#include <chrono>

#include "git2.h"
#include "WolframLibrary.h"
#include "MLExpr.h"

/// Manages all of the connectors in libgit2, including all of the callbacks.
class RemoteConnector
{
public:
	RemoteConnector(WolframLibraryData libData, git_repository* repo, const char* remoteName, const char* theKeyFile);
	~RemoteConnector();

	bool fetch() { return connect_(GIT_DIRECTION_FETCH); };
	bool push() { return connect_(GIT_DIRECTION_PUSH); };
	bool clone(git_repository** repo, const char* uri, const char* localPath, git_clone_options* options, const MLExpr& progressFunction);

	git_remote* remote() const { return remote_; };
	const git_remote_callbacks& callbacks() const { return callbacks_; };
	bool isValidRemote() const { return isValidRemote_; };

private:
	static int AcquireCredsCallback(git_cred** cred,const char* url,const char *username,unsigned int allowed_types, void* payload);
	int acquireCredsCallback_(git_cred** cred, const char* url, const char* username, unsigned int allowed_types);

	static int TransferProgressCallback(const git_transfer_progress* stats, void* payload);
	static int SidebandProgressCallback(const char* str, int len, void* payload);
	bool connect_(git_direction direction);

	std::string remoteName_;
	std::string keyFile_;
	WolframLibraryData libData_ = NULL;
	int credentialAttempts_ = 0;
	bool triedSshAgent_ = false;
	git_remote* remote_ = NULL;
	git_remote_callbacks callbacks_;
	MLExpr progressFunction_;
	std::chrono::steady_clock::time_point lastProgressCheckpoint_ = std::chrono::steady_clock::now();
	bool isValidRemote_;
};

#endif // RemoteConnector_h_
