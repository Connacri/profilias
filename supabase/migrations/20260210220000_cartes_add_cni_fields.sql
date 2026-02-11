alter table public.cartes
  add column if not exists cni_nom_ar text,
  add column if not exists cni_prenom_ar text,
  add column if not exists cni_nom_verso text,
  add column if not exists cni_prenom_verso text,
  add column if not exists cni_date_naissance date,
  add column if not exists cni_lieu_naissance text,
  add column if not exists cni_rh text,
  add column if not exists cni_recto_text text,
  add column if not exists cni_verso_text text,
  add column if not exists cni_recto_image_path text,
  add column if not exists cni_verso_image_path text;
