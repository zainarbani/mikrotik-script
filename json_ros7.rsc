{
 :local urlSample "https://jsonplaceholder.typicode.com/posts/1/comments";
 :local jsonSample [:deserialize value=([/tool fetch url=$urlSample output=user as-value]->"data") from=json];
 :for i from=0 to=([:len $jsonSample] - 1) do={
  :put ($jsonSample->$i->"email");
 }
}
