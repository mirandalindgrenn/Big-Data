#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

params.mzMLData = "/crex/proj/uppmax2026-1-94/metabolomics/mzMLData/*.mzML"

process process_masstrace_detection_pos_OpenMS {

    input:
    path mzmlFile
    path settingFile

    output:
    path "${mzmlFile.baseName}.featureXML"

    script:
    """
    FeatureFinderMetabo \\
        -in ${mzmlFile} \\
        -out ${mzmlFile.baseName}.featureXML \\
        -ini ${settingFile}
    """
}


process process_masstrace_alignment_pos_OpenMS {

    memory '12 GB'

    input:
    path featureFiles
    path settingFile

    output:
    path "out/*.featureXML"

    script:
    def inputFiles = featureFiles.collect { it.name }.join(' ')
    def outputFiles = featureFiles.collect { "out/${it.name}" }.join(' ')

    """
    mkdir -p out

    MapAlignerPoseClustering \\
        -in ${inputFiles} \\
        -out ${outputFiles} \\
        -ini ${settingFile}
    """
}


process process_masstrace_linker_pos_OpenMS {

    memory '12 GB'

    input:
    path alignedFiles
    path settingFile

    output:
    path "Aggregated.consensusXML"

    script:
    def inputFiles = alignedFiles.collect { it.name }.join(' ')

    """
    FeatureLinkerUnlabeledQT \\
        -in ${inputFiles} \\
        -out Aggregated.consensusXML \\
        -ini ${settingFile}
    """
}


process process_masstrace_exporter_pos_OpenMS {

    publishDir "results", mode: "copy"

    input:
    path consensusFile

    output:
    path "Aggregated_clean.csv"

    script:
    """
    TextExporter \\
        -in ${consensusFile} \\
        -out Aggregated.csv

    /usr/bin/readOpenMS.r \\
        input=Aggregated.csv \\
        output=Aggregated_clean.csv
    """
}


workflow {

    mzMLFiles = Channel.fromPath(params.mzMLData)

    featureFinderIni = file("/crex/proj/uppmax2026-1-94/metabolomics/openms_params/FeatureFinder.ini")
    alignmentIni     = file("/crex/proj/uppmax2026-1-94/metabolomics/openms_params/featureAlignment.ini")
    linkerIni        = file("/crex/proj/uppmax2026-1-94/metabolomics/openms_params/featureLinker.ini")

    detectedFeatures = process_masstrace_detection_pos_OpenMS(
        mzMLFiles,
        featureFinderIni
    )

    alignedFeatures = process_masstrace_alignment_pos_OpenMS(
        detectedFeatures.collect(),
        alignmentIni
    )

    linkedFeatures = process_masstrace_linker_pos_OpenMS(
        alignedFeatures.collect(),
        linkerIni
    )

    process_masstrace_exporter_pos_OpenMS(linkedFeatures)
}
