require 'active_rdf'

class SWCAdapter < RedlandAdapter
  ConnectionPool.register_adapter(:swc, self)
  
  def initialize(params={})
    super
    
    @uris_retrieved = []
    @max_steps = params[:max_steps] || 1
  end
  
  def query(query)
    # Convert query to SPARQL if necessary
    sparql = query.kind_of?(Query) ? query.to_sp : query
    
    # Split SPARQL queries into a set of triple patterns
    triples = query_to_triples(sparql)
    # Extract any URIs in the triples
    uris = select_uris_in_triples(triples)
    
    # Dereference and fetch all URIs in the query
    uris.each { |uri| load(uri) }
      
    # Fetch rdfs:seeAlso links related to the URIs in the triple
    see_also_query = Query.new.select(:x, :y).where(:x, RDFS::seeAlso, :y)
    fetch_see_also_results(super(see_also_query), uris)
    
    test_query = Query.new
    triples.each { |t| t.each { |s| test_query.select_distinct(s) if s.kind_of? Symbol } }
    query.where_clauses.each { |w| test_query.where(w[0], w[1], w[2]) }
    results = super(test_query)
    puts Query2SPARQL.translate(query)
    p results
    results.each do |row|
      row.each do |column|
        load(column.uri) if column.respond_to? :uri
      end
    end
    
    # steps = 0
    # while (steps<@max_steps)
    #   steps+=1
    #   
    #   results = []
    #   triples.each do |triple|
    #     triple_query = Query.new.select.where(triple[0],triple[1],triple[2])
    #     triple.each { |r| triple_query.select(r) if r.kind_of? Symbol }
    #     triple_results = super(triple_query)
    #     results << triple_results.flatten.uniq
    #   end
    #   intersection = results.first
    #   results[1,-1].each { |r| intersection & r }
    #   p results
    #   p intersection
    # end
    
    super
  end
  
	def load(location, syntax="ntriples")
    return if uri =~ %r[http://www.activerdf.org/bnode/]
    uri = $1 if uri =~ /(.*?)\#.*/
    return if @uris_retrieved.include? uri
    super
    @uris_retrieved << uri 
  end
  
  private
  
  def fetch_see_also_results(results, uris)
    return if uris.empty?
    results.each do |r|
      x, y = r.first.uri, r.last.uri
      fetch(y) if uris.include? x
    end
  end
  
  def select_uris_in_triples(triples)
    uris = []
    triples.each do |triple|
      triple.each { |e| uris << $1 if e =~ /<(.*?)>/ }
    end
    uris
  end
  
  def query_to_triples(query)
    if query =~ /\{(.*?)\}/ 
      triples = $1.split(' . ?')
      triples.map do |triple| 
        elems = triple.split(/ +/).select { |e| e.size>0 }
        elems.map! { |e| e =~ /^\?(\w+)/ ? $1.to_sym : e }
        elems[0,elems.size-1]
      end
    end
  end
end
