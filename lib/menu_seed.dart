import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> seedRestaurant(String restId) async {
  final db = FirebaseFirestore.instance;

  final menuTree = [
    // ========================= MEERESKÜCHE =========================
    {
      'id': 'cat_meer',
      'name': 'Meeresküche',
      'subcategories': [
        {
          'id': 'sub_meerklass',
          'name': 'Fisch & Meeresfrüchte',
          'dishes': [
            {'id': 'd_dorade_pfanne', 'name': 'Doradenfilet aus der Pfanne mit mediterranem Gemüse und Kartoffeln', 'price': 25.50},
            {'id': 'd_lachs_safran', 'name': 'Lachssteak vom Grill, Safran-Limetten-Sauce, Gemüse & Rosmarinkartoffeln', 'price': 25.50},
            {'id': 'd_edelfisch', 'name': 'Edelfischteller vom Grill mit mediterranem Gemüse & Rosmarinkartoffeln', 'price': 31.50},
            {'id': 'd_hering_sahne', 'name': 'Hering in Sahnesauce mit Kartoffeln', 'price': 15.50},
            {'id': 'd_linguine_garnelen_oel', 'name': 'Linguine mit 4 Riesengarnelen in Olivenöl & Knoblauch', 'price': 19.90},
            {'id': 'd_linguine_garnelen_tom', 'name': 'Linguine mit 4 Riesengarnelen in Tomatensauce & Knoblauch', 'price': 19.90},
          ],
        },
      ],
    },

    // ========================= FLEISCHLOS & VEGAN ==================
    {
      'id': 'cat_veg',
      'name': 'Fleischlos & Vegan',
      'subcategories': [
        {
          'id': 'sub_veg_main',
          'name': 'Vegetarisch / Vegan',
          'dishes': [
            {'id': 'd_ziegenkaese', 'name': 'Gratinierter Ziegenkäse mit Salat, frischen Früchten & Walnüssen', 'price': 17.50},
            {'id': 'd_maultaschen_spinat', 'name': 'Maultaschen mit Spinatfüllung in Salbeibutter', 'price': 15.50},
            {'id': 'd_spinatknoedel', 'name': 'Hausgemachter Spinatknödel mit frischem Parmesan & Salbeibutter', 'price': 15.50},
            {'id': 'd_bowl_vegan', 'name': 'Vegane Bowl mit mediterranem Gemüse', 'price': 15.50},
            {'id': 'd_kartoffelpuffer', 'name': '5 Kartoffelpuffer mit Apfelmus', 'price': 14.50},
            {'id': 'd_kaesespaetzle', 'name': 'Käsespätzle mit Röstzwiebeln & Salat', 'price': 15.50},
            {'id': 'd_gemuese_pfanne', 'name': 'Mediterrane Gemüsepfanne in Oliven-Tomaten-Jus und Käse', 'price': 14.50},
            {'id': 'd_bowl_falafel', 'name': 'Waldschenken Bowl Falafel (Couscous-Gemüse, Edamame, Zucchini, Kichererbsen, Avocado, Mango, Kirschtomaten, Sesamdressing)', 'price': 15.90},
          ],
        },
      ],
    },

    // ========================= SALATE & BEILAGEN ===================
    {
      'id': 'cat_salate',
      'name': 'Salate',
      'subcategories': [
        {
          'id': 'sub_salate',
          'name': 'Salate',
          'dishes': [
            {'id': 'd_bauernsalat', 'name': 'Bauernsalat (Rucola, Tomaten, Schafskäse, Oliven, Zwiebeln)', 'price': 13.50},
            {'id': 'd_bunter_salat', 'name': 'Bunter gemischter Salat der Saison', 'price': 12.50},
            {'id': 'd_bunter_salat_pute', 'name': 'Bunter Salat + Putenbruststreifen', 'price': 16.50},
            {'id': 'd_bunter_salat_calamari', 'name': 'Bunter Salat + Baby Calamari', 'price': 18.90},
            {'id': 'd_bunter_salat_gambas', 'name': 'Bunter Salat + Gambas', 'price': 19.90},
            {'id': 'd_bunter_salat_lachs', 'name': 'Bunter Salat + Lachs', 'price': 19.90},
          ],
        },
        {
          'id': 'sub_beilagen_klein',
          'name': 'Kleine Beilagen',
          'dishes': [
            {'id': 'd_pommes', 'name': 'Pommes', 'price': 4.50},
            {'id': 'd_kroketten', 'name': 'Kroketten', 'price': 4.50},
            {'id': 'd_rosmarinkartoffeln', 'name': 'Rosmarin-Kartoffeln', 'price': 4.50},
            {'id': 'd_bratkartoffeln', 'name': 'Bratkartoffeln', 'price': 4.50},
            {'id': 'd_roestzwiebeln', 'name': 'Röstzwiebeln', 'price': 4.50},
            {'id': 'd_kleiner_salat', 'name': 'Kleiner Salat', 'price': 4.50},
            {'id': 'd_med_gemuese', 'name': 'Mediterranes Gemüse', 'price': 4.50},
            {'id': 'd_sauce_mayo', 'name': 'Mayonnaise', 'price': 0.50},
            {'id': 'd_sauce_ketchup', 'name': 'Ketchup', 'price': 0.50},
          ],
        },
      ],
    },

    // ========================= SCHNITZEL ===========================
    {
      'id': 'cat_schnitzel',
      'name': 'Schnitzel',
      'subcategories': [
        {
          'id': 'sub_schnitzel',
          'name': 'Schnitzel',
          'dishes': [
            {'id': 'd_schn_wiener', 'name': 'Schnitzel „Wiener Art“', 'price': 17.50},
            {'id': 'd_schn_paprika', 'name': 'Paprika-Schnitzel (feurige Sauce)', 'price': 18.50},
            {'id': 'd_schn_champignon', 'name': 'Champignon-Rahm-Schnitzel', 'price': 18.50},
            {'id': 'd_schn_pfeffer', 'name': 'Pfeffer-Rahm-Schnitzel', 'price': 18.50},
            {'id': 'd_schn_zwiebel', 'name': 'Zwiebel-Schnitzel', 'price': 18.50},
            {'id': 'd_schn_hawaii', 'name': 'Hawaii-Schnitzel', 'price': 18.50},
            {'id': 'd_schn_kalb', 'name': 'Kalbschnitzel', 'price': 24.50},
          ],
        },
      ],
    },

    // ========================= FÜR KINDER ==========================
    {
      'id': 'cat_kids',
      'name': 'Für Kinder',
      'subcategories': [
        {
          'id': 'sub_kids',
          'name': 'Kindergerichte',
          'dishes': [
            {'id': 'd_kids_schnitzel_pommes', 'name': 'Schnitzel mit Pommes', 'price': 9.00},
            {'id': 'd_kids_nuggets_pommes', 'name': 'Chicken Nuggets mit Pommes', 'price': 9.00},
            {'id': 'd_kids_spaghetti', 'name': 'Spaghetti mit Tomatensauce', 'price': 9.00},
            {'id': 'd_kids_spaetzle', 'name': 'Spätzle mit Butter', 'price': 7.50},
            {'id': 'd_kids_raeuberteller', 'name': 'Räuberteller', 'price': 0.00},
          ],
        },
      ],
    },

    // ========================= DESSERTS & HOT DRINKS ===============
    {
      'id': 'cat_dessert',
      'name': 'Desserts',
      'subcategories': [
        {
          'id': 'sub_dessert',
          'name': 'Desserts',
          'dishes': [
            {'id': 'd_schokosouffle', 'name': 'Schokosoufflé mit Vanilleeis & Sahne', 'price': 7.50},
            {'id': 'd_pannacotta', 'name': 'Panna Cotta', 'price': 6.50},
            {'id': 'd_tartufo', 'name': 'Tartufo', 'price': 7.90},
            {'id': 'd_tiramisu', 'name': 'Tiramisu', 'price': 6.90},
            {'id': 'd_dessertplatte', 'name': 'Dessertplatte (Variationen) p.P.', 'price': 8.90},
            {'id': 'd_kuchen_stueck', 'name': 'Kuchen (Stück, wechselnd)', 'price': 4.70},
          ],
        },
      ],
    },
    {
      'id': 'cat_hot',
      'name': 'Warme Getränke',
      'subcategories': [
        {
          'id': 'sub_kaffee',
          'name': 'Kaffee & Tee',
          'dishes': [
            {'id': 'd_kaffee_tasse', 'name': 'Tasse Kaffee', 'price': 2.80},
            {'id': 'd_espresso', 'name': 'Espresso', 'price': 2.40},
            {'id': 'd_espresso_doppelt', 'name': 'Espresso doppelt', 'price': 4.20},
            {'id': 'd_cappuccino', 'name': 'Cappuccino', 'price': 3.50},
            {'id': 'd_latte', 'name': 'Latte Macchiato', 'price': 4.20},
            {'id': 'd_schoko', 'name': 'Heiße Schokolade mit Sahne', 'price': 3.90},
            {'id': 'd_minztee', 'name': 'Frischer Minztee (großes Glas) mit Honig', 'price': 4.50},
            {'id': 'd_bio_tee', 'name': 'Bio Tee (Julius Meinl, Sorten)', 'price': 3.50},
          ],
        },
      ],
    },

    // ========================= ALKOHOLFREIE GETRÄNKE ===============
    {
      'id': 'cat_soft',
      'name': 'Alkoholfreie Getränke',
      'subcategories': [
        {
          'id': 'sub_schorlen',
          'name': 'Schorlen',
          'dishes': [
            {'id': 'd_apfelschorle_04', 'name': 'Apfelschorle 0,4 l', 'price': 3.90},
            {'id': 'd_apfelschorle_05', 'name': 'Apfelschorle 0,5 l', 'price': 4.50},
            {'id': 'd_saftschorle_04', 'name': 'Saftschorle 0,4 l', 'price': 3.90},
            {'id': 'd_saftschorle_05', 'name': 'Saftschorle 0,5 l', 'price': 4.50},
          ],
        },
        {
          'id': 'sub_saefte',
          'name': 'Säfte',
          'dishes': [
            {'id': 'd_apfelsaft_02', 'name': 'Apfelsaft 0,2 l', 'price': 3.50},
            {'id': 'd_apfelsaft_04', 'name': 'Apfelsaft 0,4 l', 'price': 5.50},
            {'id': 'd_orangensaft_02', 'name': 'Orangensaft 0,2 l', 'price': 3.50},
            {'id': 'd_orangensaft_04', 'name': 'Orangensaft 0,4 l', 'price': 5.50},
          ],
        },
        {
          'id': 'sub_softdrinks',
          'name': 'Softdrinks',
          'dishes': [
            {'id': 'd_cola_04', 'name': 'Coca-Cola 0,4 l', 'price': 3.90},
            {'id': 'd_cola_05', 'name': 'Coca-Cola 0,5 l', 'price': 4.50},
            {'id': 'd_cola_light_04', 'name': 'Coca-Cola light 0,4 l', 'price': 3.90},
            {'id': 'd_cola_light_05', 'name': 'Coca-Cola light 0,5 l', 'price': 4.50},
            {'id': 'd_cola_zero_04', 'name': 'Coca-Cola zero 0,4 l', 'price': 3.90},
            {'id': 'd_cola_zero_05', 'name': 'Coca-Cola zero 0,5 l', 'price': 4.50},
            {'id': 'd_fanta_04', 'name': 'Fanta 0,4 l', 'price': 3.90},
            {'id': 'd_fanta_05', 'name': 'Fanta 0,5 l', 'price': 4.50},
            {'id': 'd_sprite_04', 'name': 'Sprite 0,4 l', 'price': 3.90},
            {'id': 'd_sprite_05', 'name': 'Sprite 0,5 l', 'price': 4.50},
            {'id': 'd_spezi_04', 'name': 'Spezi 0,4 l', 'price': 3.90},
            {'id': 'd_spezi_05', 'name': 'Spezi 0,5 l', 'price': 4.50},
          ],
        },
        {
          'id': 'sub_limo',
          'name': 'Limonaden',
          'dishes': [
            {'id': 'd_ginger_02', 'name': 'Ginger Ale 0,2 l', 'price': 3.50},
            {'id': 'd_ginger_04', 'name': 'Ginger Ale 0,4 l', 'price': 5.50},
            {'id': 'd_bitter_02', 'name': 'Bitter Lemon 0,2 l', 'price': 3.50},
            {'id': 'd_bitter_04', 'name': 'Bitter Lemon 0,4 l', 'price': 5.50},
            {'id': 'd_tonic_02', 'name': 'Tonic Water 0,2 l', 'price': 3.50},
            {'id': 'd_tonic_04', 'name': 'Tonic Water 0,4 l', 'price': 5.50},
          ],
        },
        {
          'id': 'sub_wasser',
          'name': 'Wasser',
          'dishes': [
            {'id': 'd_wasser_still_025', 'name': 'Mineralwasser still 0,25 l', 'price': 2.50},
            {'id': 'd_wasser_still_075', 'name': 'Mineralwasser still 0,75 l', 'price': 5.90},
            {'id': 'd_wasser_med_025', 'name': 'Mineralwasser medium 0,25 l', 'price': 2.50},
            {'id': 'd_wasser_med_075', 'name': 'Mineralwasser medium 0,75 l', 'price': 5.90},
          ],
        },
      ],
    },

    // ========================= BIERE & SPRITZ ======================
    {
      'id': 'cat_bier',
      'name': 'Biere vom Fass',
      'subcategories': [
        {
          'id': 'sub_bier',
          'name': 'Bier',
          'dishes': [
            {'id': 'd_weizen_05', 'name': 'Hefeweizen 0,5 l', 'price': 4.70},
            {'id': 'd_weizen_alkfrei_05', 'name': 'Hefeweizen alkoholfrei 0,5 l', 'price': 4.70},
            {'id': 'd_kristall_05', 'name': 'Kristallweizen 0,5 l', 'price': 4.70},
            {'id': 'd_pils_03', 'name': 'Pils 0,3 l', 'price': 3.70},
            {'id': 'd_pils_05', 'name': 'Pils 0,5 l', 'price': 4.70},
          ],
        },
      ],
    },
    {
      'id': 'cat_spritz',
      'name': 'Secco & Co',
      'subcategories': [
        {
          'id': 'sub_spritz',
          'name': 'Aperitif & Spritz',
          'dishes': [
            {'id': 'd_hugo', 'name': 'Hugo', 'price': 5.50},
            {'id': 'd_aperol', 'name': 'Aperol Spritz', 'price': 6.50},
            {'id': 'd_lillet_wb', 'name': 'Lillet Wild Berry', 'price': 6.50},
            {'id': 'd_lillet_vive', 'name': 'Lillet Vive', 'price': 6.50},
            {'id': 'd_kir_royal', 'name': 'Kir Royal', 'price': 6.50},
            {'id': 'd_aperol_maracuja', 'name': 'Aperol Maracuja', 'price': 6.50},
            {'id': 'd_medusa_spritz', 'name': 'Medusa Spritz', 'price': 6.50},
          ],
        },
      ],
    },

    // ========================= OFFENE WEINE ========================
    {
      'id': 'cat_wein',
      'name': 'Offene Weine',
      'subcategories': [
        {
          'id': 'sub_weiss',
          'name': 'Weißwein',
          'dishes': [
            {'id': 'd_riesling_02', 'name': 'Riesling (feinherb) 0,2 l', 'price': 5.50},
            {'id': 'd_riesling_10', 'name': 'Riesling (feinherb) 1,0 l', 'price': 24.00},
            {'id': 'd_grauburg_02', 'name': 'Grauburgunder (trocken) 0,2 l', 'price': 5.90},
            {'id': 'd_grauburg_10', 'name': 'Grauburgunder (trocken) 1,0 l', 'price': 26.00},
            {'id': 'd_sauvblanc_02', 'name': 'Sauvignon Blanc (trocken) 0,2 l', 'price': 6.90},
            {'id': 'd_sauvblanc_10', 'name': 'Sauvignon Blanc (trocken) 1,0 l', 'price': 30.00},
          ],
        },
        {
          'id': 'sub_rose',
          'name': 'Rosé',
          'dishes': [
            {'id': 'd_rose_02', 'name': 'Rosé (trocken) 0,2 l', 'price': 5.50},
            {'id': 'd_rose_10', 'name': 'Rosé (trocken) 1,0 l', 'price': 24.00},
          ],
        },
        {
          'id': 'sub_rot',
          'name': 'Rotwein',
          'dishes': [
            {'id': 'd_rot_haus_02', 'name': 'Rotwein (Hauswein) 0,2 l', 'price': 5.50},
            {'id': 'd_rot_haus_10', 'name': 'Rotwein (Hauswein) 1,0 l', 'price': 24.00},
            {'id': 'd_primitivo_02', 'name': 'Primitivo 0,2 l', 'price': 5.90},
            {'id': 'd_primitivo_10', 'name': 'Primitivo 1,0 l', 'price': 26.00},
            {'id': 'd_cabernet_02', 'name': 'Cabernet Sauvignon 0,2 l', 'price': 5.90},
            {'id': 'd_cabernet_10', 'name': 'Cabernet Sauvignon 1,0 l', 'price': 26.00},
            {'id': 'd_spaetburg_02', 'name': 'Spätburgunder 0,2 l', 'price': 6.90},
            {'id': 'd_spaetburg_10', 'name': 'Spätburgunder 1,0 l', 'price': 30.00},
          ],
        },
      ],
    },
  ];

  await db.collection('restaurants').doc(restId).set({
    'name': 'Waldschenke',
    'tablesCount': 8,
    'tz': 'Europe/Berlin',
    'menuTree': menuTree,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}
