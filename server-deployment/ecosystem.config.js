module.exports = {
  apps: [{
    name: 'achme-backend',
    script: 'E:\\OBSIDIAN\\simple-react-spark\\backend\\server.js',
    instances: 1,
    exec_mode: 'fork',
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    restart_delay: 3000,
    max_restarts: 10,
    listen_timeout: 15000,
    kill_timeout: 5000,

    error_file: 'E:\\OBSIDIAN\\simple-react-spark\\logs\\backend-error.log',
    out_file: 'E:\\OBSIDIAN\\simple-react-spark\\logs\\backend-out.log',
    merge_logs: true,
    time: true,

    env: {
      NODE_ENV: 'production',
      PORT: 5000,
      ALLOWED_ORIGIN: 'http://localhost:5173',
      DEFAULT_TEST_PASSWORD: 'Test@12345',

      DB_HOST: '127.0.0.1',
      DB_PORT: 3306,
      DB_USER: 'root',
      DB_PASS: 'admin@123',
      DB_NAME: 'achme',

      SMTP_HOST: 'smtp.gmail.com',
      SMTP_PORT: 587,
      EMAIL_USER: 'thanan757@gmail.com',
      EMAIL_PASS: 'ghjv omqm hwji kerq',

      JWT_SECRET: '97418d0c15d57ade768586b8501e35d34e5a5277f2a0570b6d5b47ef93f5b33e88b80045c60efd77e6edcbb015dbe46cf6747ce1dd8f11361f3e426ddc677c9a'
    }
  }]
};
