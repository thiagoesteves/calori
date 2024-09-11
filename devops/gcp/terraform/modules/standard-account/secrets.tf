# ATTENTION: The values are expected to be set manually by the DASHBOARD
#

resource "google_secret_manager_secret" "deployex_secrets" {
  secret_id = "deployex-calori-${var.account_name}-secrets"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "calori_secrets" {
  secret_id = "calori-${var.account_name}-secrets"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "calori_otp_tls_ca" {
  secret_id = "calori-${var.account_name}-otp-tls-ca"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "calori_otp_tls_key" {
  secret_id = "calori-${var.account_name}-otp-tls-key"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "calori_otp_tls_crt" {
  secret_id = "calori-${var.account_name}-otp-tls-crt"
  replication {
    auto {}
  }
}
