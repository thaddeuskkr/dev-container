variable "IMAGE" {
  default = "thadkkr/vm"
}

# Local/manual builds get dated tags too; override BUILD_DATE when needed.
variable "BUILD_DATE" {
  default = formattimestamp("YYYYMMDD", timestamp())
}

group "default" {
  targets = ["dev", "sandbox"]
}

target "_common" {
  context = "."
  dockerfile = "Dockerfile"
  platforms = ["linux/amd64", "linux/arm64"]
}

target "dev" {
  inherits = ["_common"]
  target = "dev"
  tags = ["${IMAGE}:dev", "${IMAGE}:dev-${BUILD_DATE}"]
}

target "sandbox" {
  inherits = ["_common"]
  target = "sandbox"
  tags = ["${IMAGE}:sandbox", "${IMAGE}:sandbox-${BUILD_DATE}"]
}
