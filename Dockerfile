FROM haskell:9.0.1

WORKDIR /app
RUN cabal update && apt-get update

# Install Influx client 
RUN apt-get install wget gpg lsb-release -y && \
    wget -qO- https://repos.influxdata.com/influxdb.key | apt-key add - && \
    . /etc/os-release && \
    echo "deb https://repos.influxdata.com/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/influxdb.list && \
    apt-get update && \
    apt-get install influxdb2 

# Install other system dependencies
RUN apt-get install gnuplot graphviz -y

COPY ./Front.cabal /app/Front.cabal

# Build dependencies independently so they get cached separately. 
RUN cabal build --only-dependencies -j4

# Add and Install Application Code
COPY . /app
RUN cabal install

# Make a directory to hold the build results. 
RUN mkdir -p /app/results

CMD ["Front"]

#RUN pip install -r requirements.txt
#ENTRYPOINT ["python"]
#CMD ["app.py"]