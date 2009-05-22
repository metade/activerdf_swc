require 'active_rdf'

class SWCAdapter < RedlandAdapter
  ConnectionPool.register_adapter(:swc, self)
  
  def initialize(params={})
    super
    
    @uris_retrieved = []
    @max_steps = params[:max_steps] || 5
  end
  
  def query(query)
    # Convert query to SPARQL if necessary
    sparql = query.kind_of?(Query) ? query.to_sp : query
    
    # Split SPARQL queries into a set of triple patterns
    triples = query_to_triples(sparql)
    # Extract any URIs in the triples
    uris = select_uris_in_triples(triples)
    
    # Dereference and fetch all URIs in the query
    uris.each { |uri| swc_load(uri) }
      
    # Fetch rdfs:seeAlso links related to the URIs in the triple
    see_also_query = Query.new.select(:x, :y).where(:x, RDFS::seeAlso, :y)
    # fetch_see_also_results(super(see_also_query), uris)
    
    test_query = munge_query(sparql, triples)
    
    steps = 0
    while (steps<@max_steps)
      steps+=1
      
      redland_query = Redland::Query.new(test_query, 'sparql')
      query_results = @model.query_execute(redland_query)
      results = query_result_to_array(query_results)
      
      results.each do |row|
        row.each do |column|
          swc_load(column.uri) if column.respond_to? :uri
        end
      end
    end
    
    redland_query = Redland::Query.new(sparql, 'sparql')
    query_results = @model.query_execute(redland_query)
    results = query_result_to_array(query_results)
  end
  
  def swc_load(uri, syntax='rdfxml')
    return if uri =~ %r[http://www.activerdf.org/bnode/] 
    return if uri =~ %r[http://xmlns.com/foaf]
    
    uri = $1 if uri =~ /(.*?)\#.*/
    return if @uris_retrieved.include? uri
    load(uri, syntax)
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
  
  def triple_to_clause(triple)
    triple.map do |elem|
      elem.kind_of?(Symbol) ? "?#{elem.to_s}" : elem
    end.join(' ') + ' . '
  end
  
  def munge_query(query, triples = query_to_triples(query))
    bindings = extract_bindings(query)
    clauses = triples.map do |triple|
      (triple.first.kind_of? Symbol and triple.last.kind_of? Symbol) ?
        "OPTIONAL { #{triple_to_clause(triple)} }" : triple_to_clause(triple)
    end
    # query.sub(/\{(.*?)\}/, "{ #{clauses}}")
    "SELECT DISTINCT #{bindings.join(',')} WHERE { #{clauses}}"
  end
  
  def extract_bindings(query)
    query.scan(/\?(\w+) /).uniq.sort.map { |b| "?#{b}" }
  end
  
  def query_to_triples(query)
    if query =~ /\{(.*?)\}/ 
      triples = $1.split(/ \. ?/)
      triples.map do |triple| 
        elems = triple.split(/ +/).select { |e| e.size>0 }
        elems.map! { |e| e =~ /^\?(\w+)/ ? $1.to_sym : e }
      end
    end
  end
end
