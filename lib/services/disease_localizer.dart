class DiseaseLocalizer {
  // The 'Key' is what comes from labels.txt
  // The 'Value' is what you show to the Farmer
  static final Map<String, String> _hindiMap = {
    // Mango
    "Augmented_Mango_dataset_Anthracnose": "आम का एंथ्रेक्नोज (Anthracnose)",
    "Augmented_Mango_dataset_Die_Black": "आम का डाई बैक (Die Back)",
    "Augmented_Mango_dataset_Gall_Midge": "आम का गॉल मिज (Gall Midge)",
    "Augmented_Mango_dataset_Healthy": "आम (स्वस्थ)",
    "Augmented_Mango_dataset_Powdery_Mildew": "आम का पाउडरी मिल्ड्यू (Powdery Mildew)",

    // Cucumber
    "CUCUMBER_Bad": "खीरा (रोगग्रस्त)",
    "CUCUMBER_Good": "खीरा (स्वस्थ)",

    // Mandua (Finger Millet)
    "Mandua_blast": "मंडुए का ब्लास्ट रोग (Blast)",
    "Mandua_downy": "मंडुए का डाउनी मिल्ड्यू (Downy Mildew)",
    "Mandua_healthy": "मंडुआ (स्वस्थ)",
    "Mandua_mottle": "मंडुए का मोटल वायरस (Mottle Virus)",
    "Mandua_rust": "मंडुए का रतुआ (Rust)",
    "Mandua_seedling": "मंडुए का सीडलिंग ब्लाइट (Seedling Blight)",
    "Mandua_smut": "मंडुए का कंडुआ रोग (Smut)",
    "Mandua_wilt": "मंडुए का उकठा रोग (Wilt)",

    // Mulberry
    "Mulberry_Leaf_Dataset_01_ChiangMai60": "शहतूत (ChiangMai60)",
    "Mulberry_Leaf_Dataset_02_RedKing": "शहतूत (RedKing)",
    "Mulberry_Leaf_Dataset_03_WhiteKing": "शहतूत (WhiteKing)",
    "Mulberry_Leaf_Dataset_04_BlackOodTurkey": "शहतूत (BlackOodTurkey)",
    "Mulberry_Leaf_Dataset_05_TaiwanStraberry": "शहतूत (TaiwanStrawberry)",
    "Mulberry_Leaf_Dataset_06_BlackAustralia": "शहतूत (BlackAustralia)",
    "Mulberry_Leaf_Dataset_07_Buriram60": "शहतूत (Buriram60)",
    "Mulberry_Leaf_Dataset_08_Kamphaengsaeng42": "शहतूत (Kamphaengsaeng42)",
    "Mulberry_Leaf_Dataset_09_TaiwanMeacho": "शहतूत (TaiwanMeacho)",
    "Mulberry_Leaf_Dataset_10_ChiangMaiBuriram60": "शहतूत (ChiangMaiBuriram60)",

    // Pigeon Pea (Arhar)
    "Pigeon_Pea_Healthy": "अरहर (स्वस्थ)",
    "Pigeon_Pea_Leaf_Spot": "अरहर का लीफ स्पॉट (Leaf Spot)",
    "Pigeon_Pea_Leaf_webber": "अरहर का लीफ वेबर (Leaf Webber)",
    "Pigeon_Pea_Sterilic_mosaic": "अरहर का स्टेरिलिटी मोज़ेक (Sterility Mosaic)",

    // Potato
    "Potato_Leaf_Disease_Dataset_in_Uncontrolled_Environment_Bacteria": "आलू का जीवाणु रोग (Bacterial Disease)",
    "Potato_Leaf_Disease_Dataset_in_Uncontrolled_Environment_Fungi": "आलू का कवक रोग (Fungal Disease)",
    "Potato_Leaf_Disease_Dataset_in_Uncontrolled_Environment_Healthy": "आलू (स्वस्थ)",
    "Potato_Leaf_Disease_Dataset_in_Uncontrolled_Environment_Nematode": "आलू का सूत्रकृमि रोग (Nematode)",
    "Potato_Leaf_Disease_Dataset_in_Uncontrolled_Environment_Pest": "आलू का कीट (Pest)",
    "Potato_Leaf_Disease_Dataset_in_Uncontrolled_Environment_Phytopthora": "आलू का फाइटोफ्थोरा (Phytophthora)",
    "Potato_Leaf_Disease_Dataset_in_Uncontrolled_Environment_Virus": "आलू का विषाणु रोग (Virus)",

    // Rose
    "Rose_Leaf_Augmented_Dataset_Black_Spot": "गुलाब का ब्लैक स्पॉट (Black Spot)",
    "Rose_Leaf_Augmented_Dataset_Dry_Leaf": "गुलाब की सूखी पत्ती (Dry Leaf)",
    "Rose_Leaf_Augmented_Dataset_Healthy_Leaf": "गुलाब (स्वस्थ)",
    "Rose_Leaf_Augmented_Dataset_Leaf_Hole": "गुलाब की पत्ती में छेद (Leaf Hole)",

    // Sugarcane
    "SugarCane_Healthy": "गन्ना (स्वस्थ)",
    "SugarCane_Mosaic": "गन्ने का मोज़ेक रोग (Mosaic)",
    "SugarCane_RedRot": "गन्ने का लाल सड़न रोग (Red Rot)",
    "SugarCane_Rust": "गन्ने का रतुआ रोग (Rust)",
    "SugarCane_Yellow": "गन्ने का पीलापन (Yellow Leaf)",

    // Turmeric
    "Turmeric_Plant_Disease_Dry_Leaf": "हल्दी की सूखी पत्ती (Dry Leaf)",
    "Turmeric_Plant_Disease_Healthy_Leaf": "हल्दी (स्वस्थ)",
    "Turmeric_Plant_Disease_Leaf_Blotch": "हल्दी का लीफ ब्लॉच (Leaf Blotch)",
    "Turmeric_Plant_Disease_Rhizome_Disease_Root": "हल्दी का राइजोम रोग (Rhizome Disease)",
    "Turmeric_Plant_Disease_Rhizome_Healthy_Root": "हल्दी का राइजोम (स्वस्थ)",
  };

  static String getLabel(String englishLabel) {
    return _hindiMap[englishLabel] ?? englishLabel; // Fallback to English if missing
  }
}
