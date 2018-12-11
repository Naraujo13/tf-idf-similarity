require 'parallel'
require 'byebug'
# A simple document-term matrix.
module TfIdfSimilarity
  class TermCountModel
    include MatrixMethods

    # The documents in the corpus.
    attr_reader :documents
    # The set of terms in the corpus.
    attr_reader :terms
    # The average number of tokens in a document.
    attr_reader :average_document_size

    # @param [Array<Document>] documents documents
    # @param [Hash] opts optional arguments
    # @option opts [Symbol] :library :gsl, :narray, :nmatrix or :matrix (default)
    def initialize(documents, opts = {})
      @documents = documents
      #printf 'Initializing terms... '
      a = Time.now
      @terms = Set.new(documents.map(&:terms).flatten).to_a
      #printf("Done! (#{Time.now - a})\n")

      #printf 'Getting library option... '
      a = Time.now
      @library = (opts[:library] || :matrix).to_sym
      #printf("Done! (#{Time.now - a})\n")

      parallel_params = {}
      if documents.length > 100
        a = Time.now
        parallel_params[:progress] = 'Initializing big array of term frequency...'
      end

      array = Array.new(terms.length, Array.new(documents.length))
      array = Parallel.map_with_index(
        array, parallel_params
      ) do |docs_freq, index|
        docs_freq.length.times do |j|
          docs_freq[j] = documents[j].term_count(terms[index])
        end
        docs_freq
      end

      # #printf "Initializing big hash as alternative for term count... "
      # counts = {}
      # a = Time.now
      # documents.each do |doc|
      #   counts[doc.id] = {}
      #   doc.terms.each do |term|
      #     counts[doc.id][term] = doc.term_count(term)
      #   end
      # end
      # #printf("Done! (#{Time.now - a})\n")

      @matrix = initialize_matrix(array)
      @average_document_size = documents.empty? ? 0 : sum / column_size.to_f
    end

    # @param [String] term a term
    # @return [Integer] the number of documents the term appears in
    def document_count(term)
      index = terms.index(term)
      if index
        case @library
        when :gsl, :narray
          row(index).where.size
        when :nmatrix
          row(index).each.count(&:nonzero?)
        else
          vector = row(index)
          unless vector.respond_to?(:count)
            vector = vector.to_a
          end
          vector.count(&:nonzero?)
        end
      else
        0
      end
    end

    # @param [String] term a term
    # @return [Integer] the number of times the term appears in the corpus
    def term_count(term)
      index = terms.index(term)
      if index
        case @library
        when :gsl, :narray
          row(index).sum
        when :nmatrix
          row(index).each.reduce(0, :+) # NMatrix's `sum` method is slower
        else
          vector = row(index)
          unless vector.respond_to?(:reduce)
            vector = vector.to_a
          end
          vector.reduce(0, :+)
        end
      else
        0
      end
    end
  end
end
