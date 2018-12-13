require 'parallel'

module TfIdfSimilarity
  class Model
    include MatrixMethods

    extend Forwardable
    def_delegators :@model, :documents, :terms, :document_count

    # @param [Array<Document>] documents documents
    # @param [Hash] opts optional arguments
    # @option opts [Symbol] :library :gsl, :narray, :nmatrix or :matrix (default)
    def initialize(documents, opts = {})

      #puts '-- METHOD START --'
      #puts '-- Model.Initialize'

      #printf 'Initializing term count model... '
      a = Time.now
      @model = TermCountModel.new(documents, opts)
      #printf("Done! (#{Time.now - a})\n")

      @library = (opts[:library] || :matrix).to_sym

      parallel_params = {in_threads: 16}
      if documents.length > 100
        a = Time.now
        parallel_params[:progress] = 'Initializing big array of tfidf scores... '
      end

      # Allocate zeroed matrix
      @matrix = Numo::UInt16.zeros(terms.length, documents.length)

      # Parallel iteration to fill the term frequencies
      Parallel.each_with_index(terms, parallel_params) do |_, term_index|
        idf = inverse_document_frequency(terms[term_index])
        documents.length.times do |doc_index|
          @matrix[
            term_index, doc_index
          ] = term_frequency(documents[doc_index], terms[term_index]) * idf
        end
      end
    end

    # Return the term frequency–inverse document frequency.
    #
    # @param [Document] document a document
    # @param [String] term a term
    # @return [Float] the term frequency–inverse document frequency
    def term_frequency_inverse_document_frequency(document, term)
      inverse_document_frequency(term) * term_frequency(document, term)
    end
    alias_method :tfidf, :term_frequency_inverse_document_frequency

    # Returns a similarity matrix for the documents in the corpus.
    #
    # @return [GSL::Matrix,NMatrix,Matrix] a similarity matrix
    # @note Columns are normalized to unit vectors, so we can calculate the cosine
    #   similarity of all document vectors.
    def similarity_matrix
      if documents.empty?
        []
      else
        multiply_self(normalize)
      end
    end

    # Return the index of the document in the corpus.
    #
    # @param [Document] document a document
    # @return [Integer,nil] the index of the document
    def document_index(document)
      @model.documents.index(document)
    end

    # Return the index of the document with matching text.
    #
    # @param [String] text a text
    # @return [Integer,nil] the index of the document
    def text_index(text)
      @model.documents.index do |document|
        document.text == text
      end
    end
  end
end
