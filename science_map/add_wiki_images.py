import json

# 所有图片URL
image_urls = {
    "pythagoras": "https://upload.wikimedia.org/wikipedia/commons/thumb/1/1a/Kapitolinischer_Pythagoras_adjusted.jpg/400px-Kapitolinischer_Pythagoras_adjusted.jpg",
    "euclid": "https://upload.wikimedia.org/wikipedia/commons/thumb/3/30/Euklid-von-Alexandria_1.jpg/400px-Euklid-von-Alexandria_1.jpg",
    "archimedes": "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e7/Domenico-Fetti_Archimedes_1620.jpg/400px-Domenico-Fetti_Archimedes_1620.jpg",
    "zhang_heng": "https://upload.wikimedia.org/wikipedia/commons/thumb/9/91/Zhang_Heng_Seismograph.jpg/400px-Zhang_Heng_Seismograph.jpg",
    "al_khwarizmi": "https://upload.wikimedia.org/wikipedia/commons/thumb/5/53/Statue_of_Al-Khwarizmi_in_Amirkabir_University.jpg/400px-Statue_of_Al-Khwarizmi_in_Amirkabir_University.jpg",
    "ibn_al_haytham": "https://upload.wikimedia.org/wikipedia/commons/thumb/f/f3/Hazan.png/400px-Hazan.png",
    "shen_kuo": "https://upload.wikimedia.org/wikipedia/commons/thumb/6/65/Shen_Kuo.jpg/400px-Shen_Kuo.jpg",
    "fibonacci": "https://upload.wikimedia.org/wikipedia/commons/thumb/5/50/Fibonacci.jpg/400px-Fibonacci.jpg",
    "copernicus": "https://upload.wikimedia.org/wikipedia/commons/thumb/f/f2/Nikolaus_Kopernikus.jpg/400px-Nikolaus_Kopernikus.jpg",
    "vesalius": "https://upload.wikimedia.org/wikipedia/commons/thumb/4/42/Vesalius_Fabrica_portrait.jpg/400px-Vesalius_Fabrica_portrait.jpg",
    "galileo": "https://upload.wikimedia.org/wikipedia/commons/thumb/d/d4/Justus_Sustermans_-_Portrait_of_Galileo_Galilei%2C_1636.jpg/400px-Justus_Sustermans_-_Portrait_of_Galileo_Galilei%2C_1636.jpg",
    "kepler": "https://upload.wikimedia.org/wikipedia/commons/thumb/d/d4/Johannes_Kepler_1610.jpg/400px-Johannes_Kepler_1610.jpg",
    "harvey": "https://upload.wikimedia.org/wikipedia/commons/thumb/1/11/William_Harvey_%281578-1657%29_Venenbild.jpg/400px-William_Harvey_%281578-1657%29_Venenbild.jpg",
    "descartes": "https://upload.wikimedia.org/wikipedia/commons/thumb/7/73/Frans_Hals_-_Portret_van_Ren%C3%A9_Descartes.jpg/400px-Frans_Hals_-_Portret_van_Ren%C3%A9_Descartes.jpg",
    "pascal": "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a7/Blaise_Pascal_Versailles.JPG/400px-Blaise_Pascal_Versailles.JPG",
    "hooke": "https://upload.wikimedia.org/wikipedia/commons/thumb/d/d2/Robert_Hooke.jpg/400px-Robert_Hooke.jpg",
    "newton": "https://upload.wikimedia.org/wikipedia/commons/thumb/3/3b/Portrait_of_Sir_Isaac_Newton%2C_1689.jpg/400px-Portrait_of_Sir_Isaac_Newton%2C_1689.jpg",
    "leibniz": "https://upload.wikimedia.org/wikipedia/commons/thumb/6/6a/Gottfried_Wilhelm_Leibniz%2C_Bernhard_Christoph_Francke.jpg/400px-Gottfried_Wilhelm_Leibniz%2C_Bernhard_Christoph_Francke.jpg",
    "linnaeus": "https://upload.wikimedia.org/wikipedia/commons/thumb/0/05/Carolus_Linnaeus.jpg/400px-Carolus_Linnaeus.jpg",
    "lavoisier": "https://upload.wikimedia.org/wikipedia/commons/thumb/e/ed/David_-_Portrait_of_Monsieur_Lavoisier_and_His_Wife.jpg/400px-David_-_Portrait_of_Monsieur_Lavoisier_and_His_Wife.jpg",
    "volta": "https://upload.wikimedia.org/wikipedia/commons/thumb/5/52/Alessandro_Volta.jpeg/400px-Alessandro_Volta.jpeg",
    "dalton": "https://upload.wikimedia.org/wikipedia/commons/thumb/b/b4/John_Dalton_by_Charles_Turner.jpg/400px-John_Dalton_by_Charles_Turner.jpg",
    "faraday": "https://upload.wikimedia.org/wikipedia/commons/thumb/8/88/M_Faraday_Th_Phillips_oil_1842.jpg/400px-M_Faraday_Th_Phillips_oil_1842.jpg",
    "darwin": "https://upload.wikimedia.org/wikipedia/commons/thumb/2/2e/Charles_Darwin_seated_crop.jpg/400px-Charles_Darwin_seated_crop.jpg",
    "mendel": "https://upload.wikimedia.org/wikipedia/commons/thumb/b/ba/Gregor_Mendel_2.jpg/400px-Gregor_Mendel_2.jpg",
    "maxwell": "https://upload.wikimedia.org/wikipedia/commons/thumb/5/57/James_Clerk_Maxwell.png/400px-James_Clerk_Maxwell.png",
    "pasteur": "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c4/Louis_Pasteur.jpg/400px-Louis_Pasteur.jpg",
    "roentgen": "https://upload.wikimedia.org/wikipedia/commons/thumb/7/71/Roentgen2.jpg/400px-Roentgen2.jpg",
    "curie": "https://upload.wikimedia.org/wikipedia/commons/thumb/7/7e/Marie_Curie_c1920.jpg/400px-Marie_Curie_c1920.jpg",
    "planck": "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c7/Max_Planck_1933.jpg/400px-Max_Planck_1933.jpg",
    "einstein": "https://upload.wikimedia.org/wikipedia/commons/thumb/d/d3/Albert_Einstein_Head.jpg/400px-Albert_Einstein_Head.jpg",
    "rutherford": "https://upload.wikimedia.org/wikipedia/commons/thumb/6/6e/Ernest_Rutherford_LOC.jpg/400px-Ernest_Rutherford_LOC.jpg",
    "bohr": "https://upload.wikimedia.org/wikipedia/commons/thumb/6/6d/Niels_Bohr.jpg/400px-Niels_Bohr.jpg",
    "einstein_gr": "https://upload.wikimedia.org/wikipedia/commons/thumb/f/f5/Einstein_1921_by_F_Schmutzer_-_restoration.jpg/400px-Einstein_1921_by_F_Schmutzer_-_restoration.jpg",
    "quantum": "https://upload.wikimedia.org/wikipedia/commons/thumb/1/1c/Schroedinger_cat.svg/400px-Schroedinger_cat.svg.png",
    "penicillin": "https://upload.wikimedia.org/wikipedia/commons/thumb/b/b3/Penicillium_chrysogenum.jpg/400px-Penicillium_chrysogenum.jpg",
    "hubble": "https://upload.wikimedia.org/wikipedia/commons/thumb/4/4d/Edwin_Powell_Hubble.JPG/400px-Edwin_Powell_Hubble.JPG",
    "nuclear_fission": "https://upload.wikimedia.org/wikipedia/commons/thumb/1/15/Nuclear_fission.svg/400px-Nuclear_fission.svg.png",
    "transistor": "https://upload.wikimedia.org/wikipedia/commons/thumb/2/21/Transistorer_%28cropped%29.jpg/400px-Transistorer_%28cropped%29.jpg",
    "dna": "https://upload.wikimedia.org/wikipedia/commons/thumb/4/4c/DNA_Structure%2BKey%2BLabelled.pn_NoBB.png/400px-DNA_Structure%2BKey%2BLabelled.pn_NoBB.png",
    "laser": "https://upload.wikimedia.org/wikipedia/commons/thumb/f/f0/Laser_Interference.JPG/400px-Laser_Interference.JPG",
    "moon_landing": "https://upload.wikimedia.org/wikipedia/commons/thumb/9/98/Aldrin_Apollo_11_original.jpg/400px-Aldrin_Apollo_11_original.jpg",
    "internet": "https://upload.wikimedia.org/wikipedia/commons/thumb/3/3f/Internet_map_1024.jpg/400px-Internet_map_1024.jpg",
    "pcr": "https://upload.wikimedia.org/wikipedia/commons/thumb/9/96/PCR_tubes.jpg/400px-PCR_tubes.jpg",
    "www": "https://upload.wikimedia.org/wikipedia/commons/thumb/b/b2/WWW_logo_by_Robert_Cailliau.svg/400px-WWW_logo_by_Robert_Cailliau.svg.png",
    "crispr": "https://upload.wikimedia.org/wikipedia/commons/thumb/8/87/CRISPR-Cas9-mechanism.png/400px-CRISPR-Cas9-mechanism.png",
    "gravitational_waves": "https://upload.wikimedia.org/wikipedia/commons/thumb/d/db/LIGO_measurement_of_gravitational_waves.svg/400px-LIGO_measurement_of_gravitational_waves.svg.png",
    "black_hole_image": "https://upload.wikimedia.org/wikipedia/commons/thumb/4/4f/Black_hole_-_Messier_87_crop_max_res.jpg/400px-Black_hole_-_Messier_87_crop_max_res.jpg",
}

# 读取JSON
with open("assets/events.json", "r", encoding="utf-8") as f:
    events = json.load(f)

# 添加图片URL
count = 0
for event in events:
    if event["id"] in image_urls:
        event["image_url"] = image_urls[event["id"]]
        count += 1
        print(f"✅ {event['title']}: 已添加图片")

# 保存
with open("assets/events.json", "w", encoding="utf-8") as f:
    json.dump(events, f, ensure_ascii=False, indent=2)

print(f"\n🎉 完成！共添加 {count} 张图片")
