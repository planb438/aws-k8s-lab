#################################
# Outputs
#################################

output "master_public_ip" {
  description = "Public IP of the master node"
  value       = aws_instance.master.public_ip
}

output "master_private_ip" {
  description = "Private IP of the master node"
  value       = aws_instance.master.private_ip
}

output "worker_public_ips" {
  description = "Public IPs of worker nodes"
  value       = aws_instance.workers[*].public_ip
}

output "worker_private_ips" {
  description = "Private IPs of worker nodes"
  value       = aws_instance.workers[*].private_ip
}

output "ssh_command" {
  description = "SSH command to connect to master node"
  value       = "ssh -i k8s-lab-key.pem ubuntu@${aws_instance.master.public_ip}"
}

output "kubeconfig_command" {
  description = "Command to get kubeconfig from master"
  value       = "ssh -i k8s-lab-key.pem ubuntu@${aws_instance.master.public_ip} 'sudo cat /etc/kubernetes/admin.conf' > kubeconfig"
}