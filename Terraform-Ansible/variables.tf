variable "common_tags" {
    type = map
    default = {
        Author = "Yevhenii Kahliak"
        Project = "Technical Task"
    }
}

variable "ssh_access_to_jump_host" {
    default = ["0.0.0.0/0"]
}

variable "Name_of_Jump_host" {
    default = "Jump Instance"
}

variable "Docker_with_Nginx_container" {
    default = "Nginx Container"
}

variable "Docker_host_type" {
    default = "t3.small"
}

variable "Jump_host_type" {
    default = "t3.nano"
}
