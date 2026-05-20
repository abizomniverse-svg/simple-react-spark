const db = require("./config/database");

const sampleClients = [
  { name: "Rajesh Kumar", company_name: "Kumar Industries", phone: "9876543210", address: "Mumbai", city: "Mumbai", state: "Maharashtra", email: "rajesh@kumar.com", gst_number: "27AABCU9603R1ZM" },
  { name: "Priya Sharma", company_name: "Sharma Enterprises", phone: "9876543211", address: "Delhi", city: "Delhi", state: "Delhi", email: "priya@sharma.com", gst_number: "07AABCS1429B1Z1" },
  { name: "Amit Patel", company_name: "Patel Solutions", phone: "9876543212", address: "Ahmedabad", city: "Ahmedabad", state: "Gujarat", email: "amit@patel.com", gst_number: "24AABCP3618E1ZK" },
  { name: "Sneha Reddy", company_name: "Reddy Technologies", phone: "9876543213", address: "Hyderabad", city: "Hyderabad", state: "Telangana", email: "sneha@reddy.com", gst_number: "36AABCR4527F1ZP" },
  { name: "Vikram Singh", company_name: "Singh Corp", phone: "9876543214", address: "Jaipur", city: "Jaipur", state: "Rajasthan", email: "vikram@singh.com", gst_number: "08AABCS5638G1ZQ" },
  { name: "Anita Desai", company_name: "Desai Systems", phone: "9876543215", address: "Pune", city: "Pune", state: "Maharashtra", email: "anita@desai.com", gst_number: "27AABCD6749H1ZR" },
  { name: "Rahul Verma", company_name: "Verma Electronics", phone: "9876543216", address: "Noida", city: "Noida", state: "Uttar Pradesh", email: "rahul@verma.com", gst_number: "09AABCV7860J1ZS" },
  { name: "Kavita Joshi", company_name: "Joshi Networks", phone: "9876543217", address: "Bangalore", city: "Bangalore", state: "Karnataka", email: "kavita@joshi.com", gst_number: "29AABCK8971K1ZT" },
];

const sampleContracts = [
  { client_company: "Kumar Industries", contract_title: "AMC - Kumar Mumbai Office", contract_type: "AMC", start_date: "2025-01-01", end_date: "2025-12-31", amount_value: 50000, mobile_number: "9876543210", location_city: "Mumbai" },
  { client_company: "Sharma Enterprises", contract_title: "AMC - Sharma Delhi Branch", contract_type: "AMC", start_date: "2025-02-01", end_date: "2026-01-31", amount_value: 75000, mobile_number: "9876543211", location_city: "Delhi" },
  { client_company: "Patel Solutions", contract_title: "ALC - Patel Ahmedabad", contract_type: "ALC", start_date: "2025-03-01", end_date: "2026-02-28", amount_value: 100000, mobile_number: "9876543212", location_city: "Ahmedabad" },
  { client_company: "Reddy Technologies", contract_title: "AMC - Reddy Hyderabad", contract_type: "AMC", start_date: "2025-04-01", end_date: "2026-03-31", amount_value: 60000, mobile_number: "9876543213", location_city: "Hyderabad" },
  { client_company: "Singh Corp", contract_title: "ALC - Singh Jaipur", contract_type: "ALC", start_date: "2025-05-01", end_date: "2026-04-30", amount_value: 85000, mobile_number: "9876543214", location_city: "Jaipur" },
  { client_company: "Desai Systems", contract_title: "AMC - Desai Pune", contract_type: "AMC", start_date: "2025-06-01", end_date: "2026-05-31", amount_value: 45000, mobile_number: "9876543215", location_city: "Pune" },
];

console.log("Seeding sample clients and contracts...");

// Insert sample clients
const clientInsertSql = `INSERT IGNORE INTO clients (name, company_name, phone, address, city, state, email, gst_number, client_status) VALUES ?`;
const clientValues = sampleClients.map(c => [c.name, c.company_name, c.phone, c.address, c.city, c.state, c.email, c.gst_number, 'active']);

db.query(clientInsertSql, [clientValues], (err, result) => {
  if (err) {
    console.error("Error inserting clients:", err.message);
  } else {
    console.log(`✅ Inserted ${result.affectedRows} sample clients`);
  }

  // Insert sample contracts
  const contractInsertSql = `INSERT IGNORE INTO contracts (client_company, contract_title, contract_type, start_date, end_date, amount_value, mobile_number, location_city, created_by) VALUES ?`;
  const contractValues = sampleContracts.map(c => [c.client_company, c.contract_title, c.contract_type, c.start_date, c.end_date, c.amount_value, c.mobile_number, c.location_city, 1]);

  db.query(contractInsertSql, [contractValues], (err, result) => {
    if (err) {
      console.error("Error inserting contracts:", err.message);
    } else {
      console.log(`✅ Inserted ${result.affectedRows} sample contracts`);
    }
    db.end();
    console.log("Done!");
  });
});
