// Pairing host forked from idevice's ffi/src/pairable_host.rs with the mDNS advertising moved
// to the Swift side (NetService) to avoid the iOS multicast entitlement.
#ifndef DIONYSOS_H
#define DIONYSOS_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*DionysosReadyCb)(void *ctx,
                                const char *service_id,
                                uint16_t port,
                                const char *const *txt_keys,
                                const char *const *txt_vals,
                                size_t txt_count);

typedef void (*DionysosPinCb)(const char *pin, void *ctx);
typedef void (*DionysosAppleTvPinCb)(void *ctx);

typedef struct DionysosAppleTvSession DionysosAppleTvSession;

typedef struct {
    char *error;
    char *device_name;
    char *device_model;
    char *device_udid;
    char *pairing_file_path;
    char *host_alt_irk_hex;
} DionysosResult;

int32_t dionysos_run_host(const char *bind_addr,
                          uint16_t port,
                          const char *name,
                          const char *model,
                          const char *out_path,
                          DionysosReadyCb ready_cb,
                          DionysosPinCb pin_cb,
                          void *ctx,
                          DionysosResult *out);

DionysosAppleTvSession *dionysos_apple_tv_session_new(void);

int32_t dionysos_apple_tv_session_run(DionysosAppleTvSession *session,
                                      const char *host,
                                      uint16_t port,
                                      const char *name,
                                      const char *out_path,
                                      DionysosAppleTvPinCb pin_cb,
                                      void *ctx,
                                      DionysosResult *out);

int32_t dionysos_apple_tv_session_submit_pin(DionysosAppleTvSession *session,
                                             const char *pin);

void dionysos_apple_tv_session_cancel(DionysosAppleTvSession *session);
void dionysos_apple_tv_session_free(DionysosAppleTvSession *session);

void dionysos_result_free(DionysosResult *r);


/* ---- On-device sideloading (rust/src/install.rs) ---- */

typedef void (*DionysosProgressCb)(void *ctx, const char *stage, double fraction); /* fraction < 0: indeterminate */
typedef void (*DionysosPromptCb)(void *ctx, int32_t kind, const char *json);       /* 1 = two-factor, 2 = revoke certificates */

typedef struct {
    const char *host;
    uint16_t port;
    const char *identifier; /* TXT "identifier" of _remotepairing._tcp */
    const char *auth_tag;   /* TXT "authTag" */
} DionysosEndpoint;

typedef struct {
    const char *apple_id;
    const char *password;
    const char *anisette_url;
    const char *pairing_file_path;
    const char *host_name;
    const DionysosEndpoint *endpoints;
    size_t endpoint_count;
    const char *ipa_path;
    const char *device_name;
    const char *machine_name;
    const char *server_id;
} DionysosInstallConfig;

typedef struct {
    char *error;
    char *bundle_id;
    char *app_name;
    char *app_version;
    char *udid;
    char *team_id;
    int64_t expiration_unix;
} DionysosInstallResult;

typedef struct DionysosInstallSession DionysosInstallSession;

DionysosInstallSession *dionysos_install_session_new(void);
int32_t dionysos_install_session_run(DionysosInstallSession *session,
                                    const DionysosInstallConfig *config,
                                    DionysosProgressCb progress_cb,
                                    DionysosPromptCb prompt_cb,
                                    void *ctx,
                                    DionysosInstallResult *out);
int32_t dionysos_install_session_respond(DionysosInstallSession *session, const char *response);
void dionysos_install_session_cancel(DionysosInstallSession *session);
void dionysos_install_session_free(DionysosInstallSession *session);
void dionysos_install_result_free(DionysosInstallResult *r);


/* ---- Certificate manager: your own Apple ID (rust/src/install.rs) ---- */

/* Runs {"op":"overview"}, {"op":"revoke","serials":[...]} or
   {"op":"delete_app_ids","ids":[...]} against the Apple
   ID's own team. Reuses an DionysosInstallSession for 2FA prompts and cancel.
   Returns 0 with overview JSON in *out_json, or 1 with an error message.
   Free *out_json with dionysos_string_free. Blocking. */
int32_t dionysos_account_session_run(DionysosInstallSession *session,
                                    const char *apple_id,
                                    const char *password,
                                    const char *anisette_url,
                                    const char *request_json,
                                    DionysosProgressCb progress_cb,
                                    DionysosPromptCb prompt_cb,
                                    void *ctx,
                                    char **out_json);
void dionysos_string_free(char *s);


/* ---- Device ops: on-device AltServer + files into apps (rust/src/install/device.rs) ---- */

/* Opens the tunnel from config (pairing_file_path, host_name, endpoints; the
   Apple ID fields are ignored) and runs one op from request_json:
   install_app, install_profiles, remove_profiles, remove_app, list_apps, place_file.
   Returns 0 with result JSON in *out_json, or 1 with an error message.
   Free *out_json with dionysos_string_free. Blocking. */
int32_t dionysos_device_run(const DionysosInstallConfig *config,
                           const char *request_json,
                           DionysosProgressCb progress_cb,
                           void *ctx,
                           char **out_json);

#ifdef __cplusplus
}
#endif

#endif // DIONYSOS_H
