import 'package:flutter/material.dart';

import '../pokemon_detail/dossier_page.dart';

/// Opens a Pokémon's research dossier on the root navigator.
void openDossier(BuildContext context, int id) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => DossierPage(id: id)));
}
