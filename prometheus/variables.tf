variable "my_network_cidr" {
  description = "CIDR allowed to reach SSH (22) and the Prometheus UI (9090). Widened to the carrier range because the SIM router's public IP rotates within it."
  type        = string
  default     = "27.125.0.0/16"
}
