class CompanyConnectionEdge < ActiveCypher::Edge
  from_class :Company
  to_class :Company
  type :COMPANY_EDGE
end

