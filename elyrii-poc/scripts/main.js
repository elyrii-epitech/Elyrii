// main.js
document.addEventListener('DOMContentLoaded', () => {
    const form = document.getElementById('signupForm');
    if (form) {
      form.addEventListener('submit', async (event) => {
        event.preventDefault();
  
        const pseudo = form.username.value.trim();
        const email = form.email.value.trim();
        const password = form.password.value.trim();
  
        try {
          const response = await fetch('http://localhost:3000/api/signup', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json'
            },
            body: JSON.stringify({
              username: pseudo,
              email: email,
              password: password
            })
          });
  
          if (!response.ok) {
            const errorData = await response.json();
            alert(`Erreur: ${errorData.error || 'Inconnue'}`);
          } else {
            const data = await response.json();
            alert(`Inscription réussie ! Bienvenue ${data.user.username}.`);
          }
  
        } catch (error) {
          console.error('Erreur requête:', error);
          alert('Impossible de contacter le serveur. Vérifie qu\'il est bien lancé !');
        }
      });
    }
  });
  