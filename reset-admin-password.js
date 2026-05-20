const mysql = require('mysql2');
const bcrypt = require('bcryptjs');

const pool = mysql.createConnection({
  host: '127.0.0.1',
  port: 3306,
  user: 'root',
  password: 'admin@123',
  database: 'achme'
});

const newPassword = 'admin123';

bcrypt.hash(newPassword, 10, (err, hash) => {
  if (err) {
    console.error('Hash error:', err);
    process.exit(1);
  }
  
  console.log('Generated hash:', hash);
  console.log('Hash length:', hash.length);
  
  pool.query('UPDATE users SET user_password = ? WHERE email = ?', [hash, 'Kk@achmecommunication.com'], (err, result) => {
    if (err) {
      console.error('Update error:', err);
      process.exit(1);
    }
    
    console.log('Updated rows:', result.affectedRows);
    
    pool.query('SELECT LENGTH(user_password) as len, user_password FROM users WHERE email = ?', ['Kk@achmecommunication.com'], (err, rows) => {
      if (err) {
        console.error('Select error:', err);
        process.exit(1);
      }
      
      console.log('Stored hash length:', rows[0].len);
      console.log('Stored hash:', rows[0].user_password);
      
      bcrypt.compare(newPassword, rows[0].user_password, (err, match) => {
        console.log('Password match:', match);
        pool.end();
        process.exit(match ? 0 : 1);
      });
    });
  });
});
