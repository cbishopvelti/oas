# defmodule Oas.BankMatcher do
#   require Explorer.DataFrame

#   def setup_model do
#     # Load the BERT model for sentence embeddings
#     # {:ok, model_info} = Bumblebee.load_model({:hf, "sentence-transformers/all-MiniLM-L6-v2"})
#     # {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, "sentence-transformers/all-MiniLM-L6-v2"})

#     # Bat
#     # {:ok, model_info} = Bumblebee.load_model({:hf, "sentence-transformers/paraphrase-MiniLM-L3-v2"})
#     # {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, "sentence-transformers/paraphrase-MiniLM-L3-v2"})

#     # {:ok, model_info} = Bumblebee.load_model({:hf, "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"})
#     # {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"})

#     {:ok, model_info} = Bumblebee.load_model({:hf, "Lihuchen/pearl_small"})
#     {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, "Lihuchen/pearl_small"})



#     # https://github.com/lexmag/simetric
#     # https://github.com/patrickdet/fuzzy_compare

#     # Create a featurizer that will convert text to embeddings
#     serving = Bumblebee.Text.text_embedding(model_info, tokenizer)

#     %{
#       serving: serving,
#       model_info: model_info,
#       tokenizer: tokenizer
#     }
#   end

#   def get_embedding(serving, text) do
#     # Process a single text through the model to get its embedding
#     %{embedding: embedding} = Nx.Serving.run(serving, text)
#     embedding
#   end

#   def similarity(embedding1, embedding2) do
#     # Calculate cosine similarity between two embeddings
#     dot_product = Nx.dot(embedding1, Nx.transpose(embedding2))
#     norm1 = Nx.sqrt(Nx.sum(Nx.multiply(embedding1, embedding1)))
#     norm2 = Nx.sqrt(Nx.sum(Nx.multiply(embedding2, embedding2)))
#     Nx.divide(dot_product, Nx.multiply(norm1, norm2))
#   end

#   def match_name(person_name, bank_names, threshold \\ 0.7) do
#     # Set up the model
#     %{serving: serving} = setup_model()

#     # Get embeddings
#     person_embedding = get_embedding(serving, person_name)
#     bank_embeddings = Enum.map(bank_names, fn name -> {name, get_embedding(serving, name)} end)

#     # Calculate similarities and find best match
#     bank_embeddings
#     |> Enum.map(fn {name, emb} -> {name, similarity(person_embedding, emb)} end)
#     |> Enum.sort_by(fn {_, sim} -> sim end, :desc)
#     |> Enum.filter(fn {_, sim} -> Nx.to_number(sim) >= threshold end)
#   end

#   # Oas.BankMatcher.test()
#   def test do
#     t0 = DateTime.utc_now()
#     match_name("CHRIS BISHOP", ["CHRIS", "C BISHOP"])
#     DateTime.diff(DateTime.utc_now(), t0)
#   end

# end
