local config = require("lapis.config")

config("development", {
    server = "cqueues",
    port = 8080,
    bind_host = "0.0.0.0"
})

config("production", {
    server = "cqueues",
    port = 8080,
    bind_host = "0.0.0.0"
})