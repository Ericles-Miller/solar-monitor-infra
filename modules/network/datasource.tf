# Só zonas comuns da região (sem Local Zones nem Wavelength, que pedem ativação).
data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}
