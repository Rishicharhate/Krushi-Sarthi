"""The 38 PlantVillage classes the local checkpoint predicts, in the exact
order its output layer expects, plus a small farmer-facing knowledge base per
class (crop, plain-language name, description, symptoms, recommendation).

The checkpoint (`Daksh159/plant-disease-mobilenetv2` on Hugging Face) ships
with no `class_names.json` in the repo despite its README mentioning one, so
this order is NOT taken from the model card — it is the standard PlantVillage
/ "New Plant Diseases Dataset (Augmented)" alphabetical directory ordering
(the near-universal convention for 38-class PlantVillage notebooks, and what
you get from `torchvision.datasets.ImageFolder` or Keras `flow_from_directory`
over that dataset). It was verified empirically before trusting it: 5 labeled
reference photos (one per crop family) downloaded from the public
spMohanty/PlantVillage-Dataset mirror were run through the loaded checkpoint
and every one top-1-matched its known label at >99% confidence. See
docs/IMPLEMENTATION_PLAN.md §1.1 for why this checkpoint's confidence should
still never be trusted blindly on real field photos.
"""

PLANT_DISEASE_CLASSES: list[str] = [
    "Apple___Apple_scab",
    "Apple___Black_rot",
    "Apple___Cedar_apple_rust",
    "Apple___healthy",
    "Blueberry___healthy",
    "Cherry_(including_sour)___Powdery_mildew",
    "Cherry_(including_sour)___healthy",
    "Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot",
    "Corn_(maize)___Common_rust_",
    "Corn_(maize)___Northern_Leaf_Blight",
    "Corn_(maize)___healthy",
    "Grape___Black_rot",
    "Grape___Esca_(Black_Measles)",
    "Grape___Leaf_blight_(Isariopsis_Leaf_Spot)",
    "Grape___healthy",
    "Orange___Haunglongbing_(Citrus_greening)",
    "Peach___Bacterial_spot",
    "Peach___healthy",
    "Pepper,_bell___Bacterial_spot",
    "Pepper,_bell___healthy",
    "Potato___Early_blight",
    "Potato___Late_blight",
    "Potato___healthy",
    "Raspberry___healthy",
    "Soybean___healthy",
    "Squash___Powdery_mildew",
    "Strawberry___Leaf_scorch",
    "Strawberry___healthy",
    "Tomato___Bacterial_spot",
    "Tomato___Early_blight",
    "Tomato___Late_blight",
    "Tomato___Leaf_Mold",
    "Tomato___Septoria_leaf_spot",
    "Tomato___Spider_mites Two-spotted_spider_mite",
    "Tomato___Target_Spot",
    "Tomato___Tomato_Yellow_Leaf_Curl_Virus",
    "Tomato___Tomato_mosaic_virus",
    "Tomato___healthy",
]

assert len(PLANT_DISEASE_CLASSES) == 38


def _healthy(crop: str) -> dict[str, str | None]:
    return {
        "crop": crop,
        "display_name": f"Healthy {crop} Leaf",
        "description": "No disease symptoms detected.",
        "symptoms": None,
        "recommendation": "Continue regular monitoring, balanced fertilization and routine field sanitation.",
    }


DISEASE_INFO: dict[str, dict[str, str | None]] = {
    "Apple___Apple_scab": {
        "crop": "Apple",
        "display_name": "Apple Scab",
        "description": "A fungal disease (Venturia inaequalis) that thrives in cool, wet spring weather and overwinters in fallen leaves.",
        "symptoms": "Olive-green to black velvety spots on leaves and fruit; infected leaves may yellow and drop early; fruit can develop corky, cracked lesions.",
        "recommendation": "Rake and destroy fallen leaves to remove the overwintering source. Apply a protectant fungicide starting at bud break in scab-prone seasons, and favor resistant varieties where possible.",
    },
    "Apple___Black_rot": {
        "crop": "Apple",
        "display_name": "Apple Black Rot",
        "description": "A fungal disease (Botryosphaeria obtusa) that affects leaves, fruit and bark, often entering through wounds or dead wood.",
        "symptoms": "Purple-bordered brown leaf spots ('frog-eye leaf spot'), and fruit that rots from the blossom end, turning black and mummified.",
        "recommendation": "Prune out dead or cankered wood and remove mummified fruit — they carry the fungus over winter. Apply fungicide during the growing season if pressure is high.",
    },
    "Apple___Cedar_apple_rust": {
        "crop": "Apple",
        "display_name": "Cedar Apple Rust",
        "description": "A fungal disease that needs both an apple tree and a nearby juniper/cedar host to complete its life cycle.",
        "symptoms": "Bright yellow-orange spots on leaves that enlarge through summer, with small black dots appearing on the upper spot surface.",
        "recommendation": "Remove nearby juniper/cedar hosts if practical, or apply a protectant fungicide from pink bud stage through several weeks after petal fall.",
    },
    "Apple___healthy": _healthy("Apple"),
    "Blueberry___healthy": _healthy("Blueberry"),
    "Cherry_(including_sour)___Powdery_mildew": {
        "crop": "Cherry",
        "display_name": "Cherry Powdery Mildew",
        "description": "A fungal disease favored by warm days, cool nights and high humidity; spreads by windborne spores.",
        "symptoms": "White powdery fungal growth on young leaves and shoot tips; leaves may curl, pucker or show pale blotches.",
        "recommendation": "Improve air circulation with proper pruning, avoid excess nitrogen, and apply a sulfur-based or approved fungicide at first sign of infection.",
    },
    "Cherry_(including_sour)___healthy": _healthy("Cherry"),
    "Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot": {
        "crop": "Corn (Maize)",
        "display_name": "Gray Leaf Spot",
        "description": "A fungal disease (Cercospora zeae-maydis) that survives in corn residue and spreads in warm, humid conditions with heavy dew.",
        "symptoms": "Small tan to gray rectangular lesions running parallel to leaf veins, which can merge and blight large areas of the leaf.",
        "recommendation": "Rotate away from corn for a season, till under infected residue, and choose resistant hybrids. Fungicide can help if pressure is high at a critical growth stage.",
    },
    "Corn_(maize)___Common_rust_": {
        "crop": "Corn (Maize)",
        "display_name": "Common Rust",
        "description": "A fungal disease (Puccinia sorghi) that produces wind-dispersed spores and favors cool, moist conditions.",
        "symptoms": "Small, cinnamon-brown, powdery pustules scattered on both leaf surfaces, darkening as the season progresses.",
        "recommendation": "Most modern hybrids tolerate common rust well; fungicide is rarely needed unless infection is severe and the crop is still young.",
    },
    "Corn_(maize)___Northern_Leaf_Blight": {
        "crop": "Corn (Maize)",
        "display_name": "Northern Leaf Blight",
        "description": "A fungal disease (Exserohilum turcicum) that overwinters in crop residue and spreads in humid weather.",
        "symptoms": "Long, cigar-shaped grayish-green to tan lesions on leaves, typically starting on lower leaves and moving upward.",
        "recommendation": "Rotate crops, till residue, and plant resistant hybrids. Fungicide can protect yield if disease appears before or during tasseling.",
    },
    "Corn_(maize)___healthy": _healthy("Corn (Maize)"),
    "Grape___Black_rot": {
        "crop": "Grape",
        "display_name": "Grape Black Rot",
        "description": "A fungal disease (Guignardia bidwellii) most damaging in warm, humid weather; overwinters in mummified berries and canes.",
        "symptoms": "Small tan leaf spots with dark borders; berries shrivel into hard black 'mummies'.",
        "recommendation": "Remove mummified berries and prune out infected canes. Apply fungicide from early shoot growth through berry set in disease-prone seasons.",
    },
    "Grape___Esca_(Black_Measles)": {
        "crop": "Grape",
        "display_name": "Esca (Black Measles)",
        "description": "A complex fungal trunk disease that develops over years, often linked to pruning wounds.",
        "symptoms": "Interveinal 'tiger-stripe' scorching on leaves, and berries with small dark spots that can shrivel; vines may collapse suddenly in hot weather.",
        "recommendation": "Prune out and destroy affected wood during dry weather and protect cuts. There is no curative spray — focus on prevention and vine sanitation.",
    },
    "Grape___Leaf_blight_(Isariopsis_Leaf_Spot)": {
        "crop": "Grape",
        "display_name": "Grape Leaf Blight (Isariopsis Leaf Spot)",
        "description": "A fungal disease that develops on leaves in warm, humid conditions and can cause early defoliation.",
        "symptoms": "Irregular dark brown spots on leaves that enlarge and merge, often leading to premature leaf drop.",
        "recommendation": "Improve canopy airflow through leaf pulling, remove fallen infected leaves, and apply fungicide if the disease is recurring in your vineyard.",
    },
    "Grape___healthy": _healthy("Grape"),
    "Orange___Haunglongbing_(Citrus_greening)": {
        "crop": "Citrus (Orange)",
        "display_name": "Citrus Greening (Huanglongbing)",
        "description": "A serious bacterial disease spread by the Asian citrus psyllid; there is no cure once a tree is infected.",
        "symptoms": "Blotchy, asymmetric yellowing of leaves (unlike uniform nutrient-deficiency yellowing), lopsided and bitter fruit, and gradual tree decline.",
        "recommendation": "This is a notifiable/quarantine disease in most regions — report suspected cases to your local agriculture department immediately, control the psyllid vector, and remove confirmed infected trees to protect the rest of the orchard.",
    },
    "Peach___Bacterial_spot": {
        "crop": "Peach",
        "display_name": "Peach Bacterial Spot",
        "description": "A bacterial disease (Xanthomonas) favored by warm, wet, windy weather that spreads via rain splash.",
        "symptoms": "Small angular, water-soaked leaf spots that turn purple-brown, often with a 'shot-hole' appearance; fruit develops dark, pitted lesions.",
        "recommendation": "Avoid overhead irrigation, prune for airflow, and apply copper-based bactericide during dormancy and early season; resistant varieties help long-term.",
    },
    "Peach___healthy": _healthy("Peach"),
    "Pepper,_bell___Bacterial_spot": {
        "crop": "Bell Pepper",
        "display_name": "Bacterial Leaf Spot (Pepper)",
        "description": "A bacterial disease that spreads rapidly in warm, wet, humid conditions, often via splashing water and contaminated tools or seed.",
        "symptoms": "Small, dark, water-soaked spots on leaves and fruit that may have a yellow halo; heavily spotted leaves can yellow and drop.",
        "recommendation": "Use certified disease-free seed/transplants, avoid working in wet fields, rotate crops, and apply a copper-based bactericide preventively in humid weather.",
    },
    "Pepper,_bell___healthy": _healthy("Bell Pepper"),
    "Potato___Early_blight": {
        "crop": "Potato",
        "display_name": "Potato Early Blight",
        "description": "A fungal disease (Alternaria solani) that typically appears on older, lower leaves first, especially on stressed plants.",
        "symptoms": "Dark brown spots with concentric 'target' rings, surrounded by a yellow halo; heavily infected leaves yellow and die early.",
        "recommendation": "Rotate crops away from potato/tomato, ensure balanced nitrogen to avoid plant stress, and apply fungicide once early spots appear, especially in warm, humid weather.",
    },
    "Potato___Late_blight": {
        "crop": "Potato",
        "display_name": "Potato Late Blight",
        "description": "A fast-moving, historically devastating disease (Phytophthora infestans, the Irish Famine pathogen) that spreads explosively in cool, wet weather.",
        "symptoms": "Water-soaked, dark green to black lesions on leaves that expand rapidly, often with white fungal growth on the underside in humid conditions; can destroy a field within days.",
        "recommendation": "Act immediately — this disease spreads fast. Remove and destroy infected plants, apply a protectant/curative fungicide without delay, avoid overhead irrigation, and warn neighboring farmers since it spreads readily between fields.",
    },
    "Potato___healthy": _healthy("Potato"),
    "Raspberry___healthy": _healthy("Raspberry"),
    "Soybean___healthy": _healthy("Soybean"),
    "Squash___Powdery_mildew": {
        "crop": "Squash",
        "display_name": "Squash Powdery Mildew",
        "description": "A very common fungal disease of cucurbits, favored by warm days, high humidity and dense canopies.",
        "symptoms": "White, powdery fungal patches on the upper and lower leaf surface, spreading to cover the whole leaf; affected leaves can yellow and die.",
        "recommendation": "Improve airflow through spacing/pruning, avoid excess nitrogen, and apply sulfur or a labeled fungicide at first sign of white patches.",
    },
    "Strawberry___Leaf_scorch": {
        "crop": "Strawberry",
        "display_name": "Strawberry Leaf Scorch",
        "description": "A fungal disease that builds up in dense, poorly ventilated plantings and overwinters on infected leaves.",
        "symptoms": "Small purple blotches on leaves that enlarge and merge, giving the leaf a scorched, reddish-purple appearance.",
        "recommendation": "Remove old/infected leaves after harvest, avoid overhead watering, ensure good plant spacing, and apply fungicide if the disease recurs.",
    },
    "Strawberry___healthy": _healthy("Strawberry"),
    "Tomato___Bacterial_spot": {
        "crop": "Tomato",
        "display_name": "Tomato Bacterial Spot",
        "description": "A bacterial disease that spreads via rain splash, contaminated tools, and infected seed, especially in warm, wet conditions.",
        "symptoms": "Small, dark, greasy-looking spots on leaves and fruit, sometimes with a yellow halo; heavily infected leaves shrivel and drop.",
        "recommendation": "Use disease-free seed/transplants, avoid overhead watering and working wet plants, and apply copper-based bactericide preventively.",
    },
    "Tomato___Early_blight": {
        "crop": "Tomato",
        "display_name": "Tomato Early Blight",
        "description": "A fungal disease (Alternaria solani) that usually starts on older, lower leaves of stressed plants.",
        "symptoms": "Dark brown spots with concentric target rings, surrounded by yellowing tissue; can also affect stems and fruit.",
        "recommendation": "Stake/prune for airflow, mulch to reduce soil splash onto leaves, rotate crops, and apply fungicide once spots appear.",
    },
    "Tomato___Late_blight": {
        "crop": "Tomato",
        "display_name": "Tomato Late Blight",
        "description": "The same fast-spreading pathogen (Phytophthora infestans) that devastates potato; can wipe out a tomato crop within days in cool, wet weather.",
        "symptoms": "Large, water-soaked, dark green-to-brown lesions on leaves and stems, often with white fungal growth on leaf undersides in humid weather; fruit develops firm, dark, greasy-looking blotches.",
        "recommendation": "Act immediately — remove and destroy infected plants, apply fungicide right away, improve airflow, avoid overhead irrigation, and warn nearby growers since it spreads between fields quickly.",
    },
    "Tomato___Leaf_Mold": {
        "crop": "Tomato",
        "display_name": "Tomato Leaf Mold",
        "description": "A fungal disease especially common in humid greenhouses or densely planted, poorly ventilated fields.",
        "symptoms": "Pale yellow spots on the upper leaf surface with olive-green to grayish-purple velvety mold on the underside.",
        "recommendation": "Improve ventilation and reduce humidity around plants, avoid overhead watering, prune for airflow, and apply fungicide if it persists.",
    },
    "Tomato___Septoria_leaf_spot": {
        "crop": "Tomato",
        "display_name": "Tomato Septoria Leaf Spot",
        "description": "A fungal disease that spreads via rain splash and typically starts on lower, older leaves.",
        "symptoms": "Numerous small circular spots with dark borders and tan/gray centers, often with tiny black specks visible in the center.",
        "recommendation": "Remove and destroy affected lower leaves, mulch to reduce soil splash, avoid overhead watering, and apply fungicide if spreading continues.",
    },
    "Tomato___Spider_mites Two-spotted_spider_mite": {
        "crop": "Tomato",
        "display_name": "Spider Mite Damage (Two-Spotted Spider Mite)",
        "description": "Damage from a tiny sap-sucking pest, not a disease, that thrives in hot, dry conditions and multiplies quickly.",
        "symptoms": "Fine yellow/white stippling or speckling on leaves, bronzing at high infestation, and fine webbing on the underside of leaves in severe cases.",
        "recommendation": "Hose down foliage to dislodge mites, encourage natural predators, and use a miticide or insecticidal soap if the infestation is heavy — avoid broad-spectrum insecticides that also kill mite predators.",
    },
    "Tomato___Target_Spot": {
        "crop": "Tomato",
        "display_name": "Tomato Target Spot",
        "description": "A fungal disease favored by warm, humid weather and prolonged leaf wetness.",
        "symptoms": "Brown spots with concentric rings similar to early blight, appearing on leaves, stems and fruit; can cause significant defoliation.",
        "recommendation": "Improve airflow and reduce leaf wetness duration, rotate crops, remove infected debris, and apply fungicide in humid, disease-prone seasons.",
    },
    "Tomato___Tomato_Yellow_Leaf_Curl_Virus": {
        "crop": "Tomato",
        "display_name": "Tomato Yellow Leaf Curl Virus",
        "description": "A viral disease transmitted by whiteflies; there is no cure once a plant is infected.",
        "symptoms": "Upward curling and yellowing of leaves, stunted growth, and significantly reduced fruit set.",
        "recommendation": "Remove and destroy infected plants to reduce virus spread, control whitefly populations (reflective mulch, sticky traps, appropriate insecticide), and use resistant varieties where available.",
    },
    "Tomato___Tomato_mosaic_virus": {
        "crop": "Tomato",
        "display_name": "Tomato Mosaic Virus",
        "description": "A highly stable, easily spread viral disease that can persist in soil and plant debris and spread via handling and tools.",
        "symptoms": "Mottled light and dark green mosaic patterning on leaves, leaf curling/distortion, and stunted growth.",
        "recommendation": "Remove and destroy infected plants, wash hands and disinfect tools between plants, avoid tobacco use near plants (a related virus source), and use resistant varieties.",
    },
    "Tomato___healthy": _healthy("Tomato"),
}

assert set(DISEASE_INFO.keys()) == set(PLANT_DISEASE_CLASSES)
