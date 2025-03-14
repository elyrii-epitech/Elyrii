const express = require('express');
const cors = require('cors');
const app = express();
const port = 3000;

app.use(cors());
app.use(express.json());

let users = [];

app.post('/api/signup', (req, res) => {
  const { username, email, password } = req.body;

  if (!username || !email || !password) {
    return res.status(400).json({ error: 'Champs manquants' });
  }

  const userExists = users.some(u => u.email === email);
  if (userExists) {
    return res.status(409).json({ error: 'Utilisateur déjà existant' });
  }

  const newUser = { id: Date.now(), username, email, password };
  users.push(newUser);

  return res.status(201).json({ message: 'Inscription réussie', user: newUser });
});

app.get('/api/users', (req, res) => {
  return res.json(users);
});

app.listen(port, () => {
  console.log(`Serveur Elyrii POC lancé sur http://localhost:${port}`);
});
