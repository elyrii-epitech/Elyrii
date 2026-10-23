/// Display French labels without changing existing saved/server values.
String profileOptionLabel(String value) =>
    const {
      'Feminin': 'Féminin',
      'Je prefere ne pas le dire': 'Je préfère ne pas le dire',
      'Gerer mon stress': 'Gérer mon stress',
      'Ameliorer mon sommeil': 'Améliorer mon sommeil',
      'Cultiver ma mindfulness': 'Cultiver ma pleine conscience',
      'Developper ma confiance': 'Développer ma confiance',
    }[value] ??
    value;
