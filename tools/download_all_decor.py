#!/usr/bin/env python3
"""Download ALL completed PixelLab decor objects to assets/sprites/decor/"""
import os
import requests
import time

PROJECT = r"C:\Users\Administrator\FallenEarth"
DECOR_DIR = os.path.join(PROJECT, "assets", "sprites", "decor")
os.makedirs(DECOR_DIR, exist_ok=True)

API_BASE = "https://api.pixellab.ai/mcp/objects"

# All decor object IDs grouped by type
DECOR_OBJECTS = {
    "decor_wall_ruin": [
        "b9cc5292-6279-45f6-b56f-d007eb48b427", "3a33f7dc-af3e-4da4-acd6-2da716e23d08",
        "079cdcf7-f265-4a7c-ab2e-14a7d204a959", "7942dc28-34a2-4612-894e-7ac59ef1f7a8",
        "cd44a5d3-0de1-4033-ac38-b363a28b4b70", "730ea30c-b51e-443a-bdf0-1a94a752e336",
        "9a1652e1-654d-4ed9-bdc5-cec642fb0b80", "3609678a-ffd0-4061-aa2d-fe558bf7afef",
        "c1340155-506b-4852-bde6-53a7b6d48ff5", "80fbf4bf-d1dd-4a76-95c8-df0a1ea62d3f",
        "e825e386-75a8-40a2-9bd2-829055d0358f", "da9c9c0b-d8c2-4cb9-aa9d-3adb10996f16",
        "bccf8fac-b505-49b0-8774-7bb1fab65dbb", "6c12edb4-a526-4ad8-aa14-71c84db75791",
        "b9c69328-c476-487a-8b59-a9edc8da1d50", "66a7e88d-52d9-491a-81fe-008482d4e289",
    ],
    "decor_crater": [
        "25c4726f-e11c-44c1-bcb6-6fc48f7ee2b5", "51ea15a1-2665-4579-9cfb-684b6ffb1596",
        "07c15def-0986-48dc-b6a0-3c26ddf2d656", "086d5b7a-8092-45b8-ae20-37467cfc0cfd",
        "f9d15fb2-9e36-4737-bf45-35f8404a2a9b", "f2b12330-11a3-49a4-8cf3-6129dc51a05e",
        "54f54d8e-3b73-4710-b7f5-469784d74b58", "20f7be8b-d2fe-4919-8ca2-e2537e5f52e2",
        "0cae8bf0-083d-4395-81dc-32d96a1f3bf1", "c621cfe6-0ebf-4da1-9ad9-9de56488163d",
        "b1c0a722-824a-4f16-83c5-8c1557adc221", "76530ad0-fa65-401b-9128-6533e4cdf07a",
        "99e2a1e6-0ed1-4153-b101-8129c03e974a", "483f5fc1-a509-4ccd-8aec-97d56f73142a",
        "4a811cb7-a898-491b-aed5-11bae829a552", "c3c43124-de40-4488-9771-cdf8bf181113",
    ],
    "decor_bones_scat": [
        "5f6ccaf2-a29d-404b-9bd6-e2e2012f324d", "b1d44598-72d5-4450-840b-41232b72191b",
        "9cfcae2b-62cd-46d7-99fb-cdee75ad5f5c", "7b6c87a3-7e51-4eb3-b080-87f0a817c302",
        "20578f5e-204d-4622-b4a6-36b5210c3fd6", "3a290149-8336-43f0-9adb-c1b57b687911",
        "c1b887a5-935c-4a59-9caf-b75fb7afeb88", "2874f10d-86a9-4194-adaa-8f75c83fc019",
        "5e094ce8-f320-4e1f-89d9-d68170303c4c", "0eae712a-ae5c-415b-9e44-f2dcdf806521",
        "9e9017f9-583a-4e59-af7b-4149d5d65748", "a557f8ff-f691-459b-8e66-cadfa27685d2",
        "f8c12eef-1c71-41e9-bb0e-2c1b990b4c7c", "38d88bf5-7214-4f64-92fa-6bc525e301c9",
        "7e1725bd-5def-4f6b-b588-cb320844b42e", "4b04f6ab-0001-47c6-a3df-7823c4419618",
    ],
    "decor_rock_charged": [
        "21d26a5b-7645-4508-8971-8506ed520d9e", "c7501c6d-2c8b-4ed3-bae6-49ca3dacc903",
        "29634434-18dd-4b58-ae24-ae4243705c1b", "ae8ab1fe-50b1-4e9d-8bd2-695631700702",
        "4adfc1aa-cf7f-40f4-8544-f802408f6c63", "ad952dbd-695d-4fae-a3df-dcb5aeaf128c",
        "76c1a4e9-e0e5-4325-88d1-0fead611dfe3", "59b27d51-77c1-48ce-a7f3-b11e040468fd",
        "f25c199c-0884-4c0c-adf5-d5b2245a0c22", "c1ad7247-6693-4959-80f9-70adc462e438",
        "2cd39d4d-96e7-4a23-9e14-d8ef64ed56e3", "2aa35206-56fc-4c03-a45a-8a19e5d8e79c",
        "eb793da7-122c-4f3a-bac2-d2ff8ca04493", "be1e98a9-6984-4b83-bfb5-7a50c277df46",
        "9192a375-e6d2-4944-8efa-ca3edb0a64b3", "1ada30d6-a5a5-4712-b61a-c2657ee42bb9",
    ],
    "decor_shrub_dead": [
        "a29a2205-4468-4e58-a519-2ba763ca667a", "b2818709-7033-4244-b26f-6bfaa902223f",
        "653d83cf-7ef5-4d77-94d6-d2eab87f061c", "91dfd6ec-f1e2-450e-92e2-97b5258a961a",
        "cf39f096-1b4a-47aa-8e51-7ba3a08f4031", "ac849b3d-92f8-4e43-9a3a-b352a5a629b6",
        "879b6ef8-b8f7-4b9c-87dd-70fbacb90d47", "af401377-9c95-472c-8a81-f10e815a3e55",
        "e0fc4cdb-0048-490c-874c-9134eefaf48a", "d151a444-b48e-4418-9bea-0a45ff75b88b",
        "292a0c04-96c9-4a2e-89db-81bd41ac5686", "c883479f-05d6-4a09-8abb-1889bd4eb593",
        "c5518b27-dffe-408e-ba35-39217b362bd6", "59859b65-3e2a-420e-b954-562c60eeb00b",
        "9f2fbafc-4f2b-4f58-a8bd-a601a2e623fa", "44a39707-f35c-4a6d-b126-47b920a16a15",
    ],
    "decor_flowers": [
        "c68db96f-5ad4-4f28-be37-cd89e9c40e73", "f485ab1f-ad69-421b-b3c4-4ff1bfefdd14",
        "da621746-92bb-47e6-9a20-f654bedd3f36", "bdb68ca6-936e-454f-89f9-e92007727b81",
        "5c170af5-473d-4598-b77a-f549314be794", "ebf5d20c-e2a9-4c9c-b165-443bfc9ce62d",
        "bd7baf2c-7d83-45e4-b925-4fc22c6916e1", "33e37461-2347-42f1-8a05-04dc9824e63b",
        "0a3962d5-be98-4093-b34e-bf3f66c0b31d", "ceb994b2-ef10-47b2-98c4-1e7d7089b217",
        "68915d54-54bf-483a-8947-d963719b4366", "4b1fa4f7-5238-4eac-94a4-1b0c490afb4d",
        "ef383ad9-cef5-4a66-baf5-e0ef7c31b3a9", "e7d90219-7929-47a8-8d3a-2b70f2c97f49",
        "8ca0f35e-9bf6-4cda-a854-07e0e2e659a2", "7c2d9e82-9367-4b06-a8bc-fe933792b19c",
    ],
    "decor_pillar_glass": [
        "8e8c922d-0f42-4c45-87ed-d1aa4e00378c", "e29bd400-7917-4efc-afcd-9d251457aaaa",
        "462353d2-5477-4f86-b219-470d3c4582b1", "081946da-b177-42b5-9d7d-7f3098bf66cc",
        "d18d055d-cda7-4be3-a837-4d35bc72473d", "eb9e7f00-bb90-4524-8c72-84bbd6f448ef",
        "84c4697b-ea0c-489c-ba80-3303c79c9f7c", "f746e242-7ebe-48b3-92d1-d2d9e2c80701",
        "99ffeec4-3d30-4c6f-9443-15cc52edc8c1", "42bb7f3d-2421-414b-8fa1-23362f84e81d",
        "c999eff7-aa1d-40d5-bc27-98eaacff0fb1", "36156b2a-2031-405b-9fff-898f655f410a",
        "956ac13a-334c-4257-95b7-9d0f200d7bd6", "f8c0601c-47f5-4cb8-ba96-44d133f1d90b",
        "689f75f7-4169-43d7-b687-9f62d95129af", "34d87625-3ca6-43a1-99cd-887bb688c627",
    ],
    "decor_bone_heap": [
        "4ebd8179-d6fb-42b9-b74b-3303bd2781ae", "ff7d1d5a-a415-4114-ae84-46b4fb5a3f30",
        "48383f81-d10b-4903-89ed-b2267ed8c678", "3ecc38da-0ca6-4ef3-88c5-dcfae28b4298",
        "ae6834fd-635b-4b07-8d99-8ab2715d2f62", "909b1da5-cc45-4414-8663-0e5d0ebf9908",
        "b28d7b5c-80ff-4647-b296-381c20beffc7", "2dbbfece-4dea-49b9-9435-0d81bc830cf4",
        "ea0af4c9-1dc3-44c7-a7c6-73630d651480", "b9d6483b-3c2a-43dd-8c3e-f0a6e46f3354",
        "b33836d0-c9d1-4513-863c-ee598eadf8ed", "b93046d3-d55d-4807-a224-307466e3d01b",
        "9dd7af3b-4b76-43d1-87b5-80a59bfeae04", "8cd02915-f549-4c7a-aa0d-569a06a296b7",
        "d32d74d5-fd95-46aa-9d4d-c459fcc80151", "57859bfa-7982-4ebe-9cff-051b03fba2b3",
    ],
    "decor_vent_toxic": [
        "04ac6bfb-2cad-4116-b65c-f39ceee4b1ff", "afae0dc3-ca41-45af-8030-756110c7ee61",
        "645ba818-ff2b-458b-a9fc-15ee4d6c673a", "9f539d27-d6eb-4d9f-9426-803f07f971b3",
        "704f05b3-aeee-4c75-b7f9-9f041822f65c", "cc855c5a-9cf1-4257-9cac-132b06be2c00",
        "27129a59-1eaf-42a1-9af6-bd22ed67511b", "b88d864d-76ab-42f5-9eca-f2f66b70f26e",
        "b5b6494f-6501-4d35-a077-146bed2afb64", "387a9256-c1e3-4907-bb9a-6f2c0388f223",
        "3c571676-57b5-4996-8224-6db34527d75b", "fa2fc422-224a-4d60-ab5c-c276c2c71f13",
        "2138ee51-9b03-48fb-9521-8501a95a05eb", "199de1f0-8bd7-4288-8899-bdc6130a70f9",
        "37a2d208-4414-449b-996d-1c1718488599", "03d0cd8f-742c-4380-957e-a698bb200a56",
    ],
    "decor_tower_base": [
        "86892391-7f89-4548-a8e0-86fc354f040a", "b81160dd-1e40-445a-904f-05f40f1721e2",
        "918c4dc3-ab39-496a-949c-30c70b963de7", "ffd4e318-de6a-462c-ae5a-0c633c23ea44",
        "eb71d759-0935-44b5-a2f7-062b8855aadf", "c842af37-ee32-4a15-8424-b95a71d8e5c3",
        "59a9d0f8-1063-4d8f-9de4-face3621b944", "73f26009-c38a-4bbe-8829-b75a95a1c857",
        "a0029ed6-d55f-42e3-bd03-2aca97064e0f", "0d860f07-6b02-484f-b7a1-3ca1cd776491",
        "dcb600a7-26a6-4d3b-84a7-09106642aab3", "538faf58-f63f-469d-a10d-5bf5ab2b84d9",
        "3b15913c-5a70-4c84-a10d-d65f605ea48a", "13ea31ce-cc52-4a61-9daa-2f74a152f9fd",
        "69a9ac75-cd77-4edc-a07d-dfc0394ed2c6", "0cb20dbd-19a0-468d-9a08-bdc0ac681ee2",
    ],
    "decor_mushroom_glow": [
        "7e7cffde-78ad-4920-a490-7c279876f92f", "3d3f6c3b-bda8-4f4c-81cb-f30de7dd0f7d",
        "c75a7ceb-11d7-44b1-af26-618d14c3e396", "3d7cfe15-35c0-48ea-8944-3f58a1e3f4f0",
        "53d691e0-f04e-468a-a87e-66609ca0b143", "3986b853-1a8c-410b-b528-3b29ca1cced4",
        "7363acb2-fea8-4014-8712-e5a7a1274c7f", "8dedd51c-5432-4aea-872e-208efda08e80",
        "d2baef8a-9970-4aae-b3e3-7a5aa6c774c0", "8681b42c-f2c5-4d4e-9dc9-3925319f543c",
        "8e4dca12-cf2e-4581-84c7-510787b1cd82", "53f3ccd1-74f6-483c-8303-58c8b8bb9026",
        "ce16883d-9cf4-4c14-8c3e-45e7a5246414", "11378eb5-a152-4138-afe2-06e6c8b45ef5",
        "f9eebee3-5fe1-480c-9a5d-47fc312152b2", "7da5bba8-312b-46e8-aeb8-6c4111d3967d",
    ],
}

downloaded = 0
skipped = 0
failed = 0

for sprite_name, obj_ids in DECOR_OBJECTS.items():
    for i, obj_id in enumerate(obj_ids):
        out_path = os.path.join(DECOR_DIR, f"{sprite_name}_{i:02d}.png")
        if os.path.exists(out_path):
            skipped += 1
            continue
        url = f"{API_BASE}/{obj_id}/download"
        try:
            r = requests.get(url, timeout=30)
            if r.status_code == 200:
                with open(out_path, "wb") as f:
                    f.write(r.content)
                downloaded += 1
                if downloaded % 10 == 0:
                    print(f"  Downloaded {downloaded} files...")
            else:
                failed += 1
                print(f"  FAIL {sprite_name}_{i:02d}: HTTP {r.status_code}")
        except Exception as e:
            failed += 1
            print(f"  ERROR {sprite_name}_{i:02d}: {e}")
        time.sleep(0.2)

print(f"\nDone: {downloaded} downloaded, {skipped} skipped (exists), {failed} failed")
print(f"Total decor files: {downloaded + skipped}")
