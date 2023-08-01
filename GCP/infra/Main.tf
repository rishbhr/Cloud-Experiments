resource "google_storage_bucket" "bucket" {
    provider = google.tf-gcp

    name = "gcp-bucket-terraform-393401"
    location = "US"
}

resource "google_storage_bucket_object" "bucket_object" {
    provider = google.tf-gcp

    name   = "index.html"
    source = "../Website/index.html"
    bucket = google_storage_bucket.bucket.name
}

resource "google_storage_object_access_control" "bucket_object_access_control" {
    provider = google.tf-gcp

    bucket = google_storage_bucket.bucket.name
    object = google_storage_bucket_object.bucket_object.name
    role   = "READER"
    entity = "allUsers"
}

# Reserver a static external IP address
resource "google_compute_global_address" "static_ip" {
    provider = google.tf-gcp

    name = "static-ip"
    # zone = "us-east1"
}

# get the managed zone
data "google_dns_managed_zone" "dns_zone" {
    provider = google.tf-gcp

    name = "rishbh-cloud"
}

# add the ip to the dns
resource "google_dns_record_set" "dns_record" {
    provider = google.tf-gcp

    name    = "website.${data.google_dns_managed_zone.dns_zone.dns_name}"
    type    = "A"
    ttl     = 300
    managed_zone = data.google_dns_managed_zone.dns_zone.name
    rrdatas = [google_compute_global_address.static_ip.address]
}

# add the cdn bucket as a cdn backend
resource "google_compute_backend_bucket" "cdn_backend_bucket" {
    provider = google.tf-gcp

    name = "cdn-backend-bucket"
    bucket_name = google_storage_bucket.bucket.name
    enable_cdn = true
}

# gcp url map
resource "google_compute_url_map" "url_map" {
    provider = google.tf-gcp

    name = "url-map"
    default_service = google_compute_backend_bucket.cdn_backend_bucket.self_link
    host_rule {
        hosts = ["*"]
        path_matcher = "allpaths"
    }
    path_matcher {
        name = "allpaths"
        default_service = google_compute_backend_bucket.cdn_backend_bucket.self_link
    }
}

# google compute http proxy
resource "google_compute_target_http_proxy" "http_proxy" {
    provider = google.tf-gcp

    name = "http-proxy"
    url_map = google_compute_url_map.url_map.self_link
}

# google compute ssl certificate
resource "google_compute_managed_ssl_certificate" "ssl_certificate" {
    provider = google.tf-gcp

    name = "ssl-certificate"
    managed {
        domains = [google_dns_record_set.dns_record.name]
    }
}

# gcp global forwarding rule
resource "google_compute_global_forwarding_rule" "forwarding_rule" {
    provider = google.tf-gcp

    name = "forwarding-rule"
    target = google_compute_target_http_proxy.http_proxy.self_link
    load_balancing_scheme = "EXTERNAL" 
    ip_protocol = "TCP"
    port_range = "80"
    ip_address = google_compute_global_address.static_ip.address
}

# gcp health check
resource "google_compute_health_check" "health_check" {
    provider = google.tf-gcp

    name = "health-check"
    check_interval_sec = 5
    timeout_sec = 5
    healthy_threshold = 2
    unhealthy_threshold = 2
    tcp_health_check {
        port = 443
    }
}