#!/usr/bin/env python3
"""Download ALL completed PixelLab resource node variants to assets/sprites/resource_nodes/"""
import os
import requests
import time
import json

PROJECT = r"C:\Users\Administrator\FallenEarth"
SPRITE_DIR = os.path.join(PROJECT, "assets", "sprites", "resource_nodes")
os.makedirs(SPRITE_DIR, exist_ok=True)

API_BASE = "https://api.pixellab.ai/mcp/objects"

# All object IDs grouped by resource type
OBJECTS = {
    "tree_withered_oak": [
        "1bf60712-4552-4a88-a6b6-c3109c99b639", "839a13fa-1003-46b8-82d2-35f97bd80b7b",
        "3c2b076d-92a7-4f99-9ca4-d6c85037f1e1", "770d9f6c-03e6-4e35-9714-df5027512665",
        "296cb8cf-5737-48c7-8f08-830dff8281ed", "fba2b68a-1ad8-44d0-9b3b-a8ad40b1b07d",
        "5d80f4be-4253-4038-a176-4fa77df9467e", "a97fcc4d-b9d7-43c5-86ce-01613b107457",
        "bc44617e-f0f3-4457-91df-4a700efd0a58", "ba009b5d-6f50-4703-b05f-9a82e9978fc9",
        "8bb5cf36-1706-446b-8c1d-158c85c6649b", "6335021a-7f9d-4776-839e-0ccc9455b91e",
        "1a2979db-6871-411a-9c89-0bcad982694d", "ba7e9438-840a-49ce-8762-18a1f6bfd1ec",
        "3d640144-d3d3-4ce7-912c-c279a5856818", "06f790ef-738b-4a42-883d-b9ff884e04b4",
    ],
    "tree_pine": [
        "76b4e95f-49d0-45cf-ac79-3bd4d3e59398", "12f1d413-057d-4d15-950c-126cae1f688e",
    ],
    "tree_ironwood": [
        "9b97a94f-a66a-4b37-9032-e8d7df7519a1", "efa98cb1-4252-4413-bd83-7deebb7c8a86",
        "8482eb18-8e78-4441-8d3a-ae8e90b5f0dd", "11e4f7a6-342f-4c6a-ad20-16857f9d3ccf",
        "c41b2146-2069-40d7-8856-62c7e082ae6b", "76059dc4-29cd-4981-9913-8f183edf6e01",
        "f4a9f476-1bbd-4253-aa03-02cc74c62cb6", "fda42b61-0fb4-4023-bfbf-7d8ba4aaaeb9",
        "ef156896-5acb-4b46-b1eb-440b584337dc", "ad02c7a7-76e8-469f-811e-8dcf097318b7",
        "f0afd9b5-eeaa-46d7-9be7-cbca4be52b19", "8ad0da6b-794c-4d66-a01f-fce991f5d138",
        "49807053-2138-4d2d-a40d-ccf24ff72937", "de61440a-2fa8-4298-aa67-193b329feddc",
        "bcfa88cb-6902-45b2-b604-fcbf2a74f516", "6f208a34-59d5-4c50-be41-a5369dc7eb0e",
    ],
    "tree_glass_cactus": [
        "1f0115ec-3168-4e77-8376-7595e813397a", "508c8bac-ffe2-4152-9c2f-cc3c3fe64bf6",
        "db66af38-e1f5-428d-accd-0cf1134759d9", "ad87fb43-704f-4175-87dd-c634a4b30019",
        "30f0b777-f6b6-4882-b1af-56b00daccc6d", "9ebaa106-e39e-4201-9603-3c2be1858090",
        "4543a995-ba43-4bb9-91c2-7964e32a802e", "ac51c9d6-a2e7-49a0-9248-4a7303132973",
        "c9620ba7-f12d-4232-8cbe-7fe028cbb748", "4c0cd33b-91d7-463a-b815-e41ac10fd767",
        "d256f53d-62f8-41a0-b9d5-27e95ef4d81e", "411c5f3f-c344-4c50-b270-03fd20cd7937",
        "25866a44-91eb-4e6c-ae23-48b47ba885d0", "88199cc3-ca1e-48d2-a5d9-153ed74b2434",
        "cdac2956-34df-49a9-960e-45cae08072dc", "322739ea-e495-45aa-98df-65a4fa78ba96",
    ],
    "ore_iron": [
        "85b97af4-5bf0-48fb-a097-358491154273", "9d8f6d98-e1f8-457d-a191-336bc3f4f932",
        "84503c6c-933e-47be-be24-9beb524e1079", "ea0b1fe2-4e4b-4fd1-93c1-f8bca99bb59e",
        "306c895d-6cad-4cfc-b4ea-885bf0a40505", "be55bf62-93b4-4ba6-94e0-65266ab23205",
        "57d19581-5ae2-4b37-b1be-608d671d49c8", "c4aa9f81-7270-4dd0-a25f-f0dd80c6fc59",
        "23de6509-d596-41e0-9df1-24bb5da6751e", "fcf3dfc8-1f2d-4158-a952-b81811279a36",
        "658f38d7-2108-4d4e-9136-e00a4ca16148", "a8255b20-d95e-428d-b6db-8eebd2f0032f",
        "2b251a54-bf4c-4a5f-9b82-900c3b6b8766", "055655a0-ecf2-4e6e-bfc3-9e501f34beb7",
        "a8ccab1f-212a-456e-a5dc-ef57ecd21c4e", "f30eb088-a8ed-497a-b79f-28812afbf4e3",
    ],
    "ore_copper": [
        "2c14ec92-ce72-4dfa-99a9-e2a41622112a", "8043b550-38da-4495-b8db-fce024c2a5ca",
        "e0077f9c-a8c6-4ebd-b31b-b775e71c4e27", "53902da0-ca1f-470c-8d57-3b2ccd0103aa",
        "505484a1-7ede-42c0-91ac-88efa3dadb95", "e899c667-5aa3-4f07-8421-df82ee65225f",
        "9c471602-394d-4424-ae55-21c962db5437", "36cd23af-b68f-40f5-bf80-b2ecbab25aa9",
        "21bb6775-f444-4fde-afd3-6319f5587029", "f0be3a85-1535-438d-ba24-00b5ede7d890",
        "86252e7c-12a9-4713-b6bb-b96d185291f4", "5431c884-8fb3-44b2-b569-c8b6bafed1a8",
        "d27a939c-a37d-4d26-8b5d-28458a048170", "5002fb34-b851-45d7-93e8-b4323a8c1c53",
        "ad6db30d-d964-411c-9a40-b808d7001dfb", "8db79307-5a2e-4c58-acdc-e39b5b734e13",
    ],
    "ore_starmetal": [
        "5d899bf0-b613-489a-8e6a-03b119d16160", "f876db52-3935-4546-aefb-13b0db063ea8",
        "6974ded0-f185-4e5a-96be-d233e8846829", "55c8e2e1-2e43-4978-bfc3-47f69714307a",
        "8a7edbb2-34ff-4c70-a012-4bcddac149ca", "343ff8aa-989b-49dd-98bd-2f772b0bdf32",
        "f8043559-1339-41eb-a541-d046d0ab7742", "7e6d0553-b431-404c-8c00-1d978cb9ad8f",
        "8a77adf8-77b2-4fd1-8737-205444c3c788", "e44fabfd-fef7-4b6b-baf6-4382308c435b",
        "bb34c340-cd11-4b9e-b87b-c947f56b8c78", "f94baca8-f8bb-481e-9e21-7704db7ce7aa",
        "2ea04eb7-fa38-4e37-a9a8-491195539c50", "52603256-e42c-4f80-bb1f-a7e98e24040d",
        "0aa7591a-9153-41aa-96ca-d521ced30c5b", "a5b6e078-ef8a-446c-8f33-609c0c86a250",
    ],
    "crystal_teal": [
        "ecdc6340-6189-4877-a89b-9d2a46a51def", "90a9b260-14ea-40b4-b818-d594184e7fee",
        "4d1b0e37-4870-4e68-96b2-267d9d7dde88", "a2d3ebb5-167d-46de-bb98-6f0869f52413",
        "834845df-ade2-4d6e-9fd3-a001285f9b0c", "0d46012e-e3b9-4f86-a4b5-c78c0522789f",
        "6fae4dd3-e392-49b4-8d1e-a1c162ee98fc", "748cda4d-e02f-4023-bd55-0a2597f8c83a",
        "d035e06a-854e-41ec-894e-f366bec916ca", "1c0feffb-ae66-4f55-8723-49be60716ba7",
        "563f31a3-6a12-4ab0-a3d1-4bca8b4606e1", "ea1fce1e-33e7-4a85-adbc-7c6c42a7d9d8",
        "96e9ce83-2a9a-4c5a-af38-60b2c7823865", "70faa59a-d85b-44b2-ad23-24ae4f48c0b9",
        "47e659bd-2862-4758-8c03-f8ed84e93f6b", "ba2b094d-d418-45e2-9f8a-82904f2a7d05",
    ],
    "crystal_void": [
        "d5ee72eb-1b6a-4c88-acd1-c78647c5e839", "7683a673-23bc-4189-8d7d-48cdd9824fd6",
        "d01fee7c-a9b2-4d18-9f27-c0e2c91bdce7", "4d797cb5-6ecc-4ec1-8201-2567e6158d80",
        "20637faf-c6a6-4a6a-8720-0146b940fb1e", "11964a1f-f602-4899-9fb4-4dea7e9062e1",
        "7c879f8b-1b0f-4c57-b5d4-7c92cbd465c3", "2d5cdb88-3240-480d-be5e-ada47270a7ad",
        "020e7f34-a694-4b43-b6fe-199a106f06fb", "8533fef4-c898-4181-a035-9f87ed33c1ea",
        "762759c6-753e-422c-9e92-dc9bf10451d4", "a35735c8-028b-49d7-8b43-6be5ca53a117",
        "68c7fb5c-ff7e-473a-a007-7b164779c690", "7eef724c-3f08-4978-8348-259a9259fe3f",
        "bf8a1f5d-ccc9-40e7-ae5a-4cd718c9ba16", "d2b3a929-f47e-415c-8889-e563e9a81673",
    ],
    "formation_rust_pipe": [
        "fd74c401-3630-430c-b15b-53a54a791b43", "8ac29687-67ee-49ec-8ac6-f34161b30b87",
        "e053bc19-d08c-414a-8f57-87945720ab2b", "f05b6a0c-18dd-4f46-b8bd-78c4b76cad97",
        "2ac689ea-39e5-4005-bb3d-8ff666035bee", "c1171927-16a9-4af8-9b21-2beeb625d3e3",
        "a0c1229c-fa1e-49b7-8599-6a08b924fb52", "5fafaa8c-b342-4ef7-ac2b-b893a3ec8f64",
        "bc3b115f-e802-4044-a771-c6f6ac54107e", "8c7045d1-9c70-43c0-8fc5-cb9c31b1f1dd",
        "bb7b4036-cc51-4595-a8ec-fbe9dd4c81aa", "f8c4eaec-bed3-4852-847a-9796c6c305c1",
        "61a88371-7b95-4cab-b3c4-5357b4ccc459", "fd85c4fc-a59b-47ff-b1f2-85ef77aacf32",
        "d9c50293-ea64-41cc-afd8-5816540eab93", "5e95909f-f93c-4534-9ccc-c9ef09815874",
    ],
}

downloaded = 0
skipped = 0
failed = 0

for sprite_name, obj_ids in OBJECTS.items():
    for i, obj_id in enumerate(obj_ids):
        out_path = os.path.join(SPRITE_DIR, f"{sprite_name}_{i:02d}.png")
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
print(f"Total files: {downloaded + skipped}")
